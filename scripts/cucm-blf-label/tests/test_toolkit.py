import contextlib
import io
import re
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import Mock, patch
import zipfile
from zeep.exceptions import ExternalReferenceForbidden

from test_blf import m, wsdl, snapshot, DEVICE


class Response:
    def __init__(self, data, status=200):
        self.data, self.status_code = data, status
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def iter_content(self, chunk_size):
        for i in range(0,len(self.data),chunk_size): yield self.data[i:i+chunk_size]


def archive(entries):
    data=io.BytesIO()
    with zipfile.ZipFile(data,'w') as z:
        for name,content in entries: z.writestr(name,content)
    return data.getvalue()


class ToolkitTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cache=Path(self.temp.name)/'schema'
        self.log=Mock()
        self.endpoint='https://example.invalid:8443/axl/'

    def run_setup(self,data,version='14.0',status=200):
        session=m.Session()
        self.addCleanup(session.close)
        session.verify=False
        session.get=Mock(return_value=Response(data,status))
        with contextlib.redirect_stdout(io.StringIO()):
            path=m.ensure_toolkit(None,self.cache,version,session,self.endpoint,30,self.log)
        return path,session

    def assert_clean(self):
        self.assertFalse((self.cache/'14.0').exists())
        if self.cache.exists(): self.assertEqual(list(self.cache.iterdir()),[])

    def test_download_detected_version_and_reuse_without_get(self):
        data=archive([('toolkit/schema/14.0/AXLAPI.wsdl',wsdl('14.0')),
                      ('toolkit/schema/15.0/AXLAPI.wsdl',wsdl('15.0')),
                      ('toolkit/bin/unneeded.exe',b'not extracted')])
        path,session=self.run_setup(data)
        self.assertEqual(path,self.cache/'14.0'/'AXLAPI.wsdl')
        self.assertEqual(path.read_text(),wsdl('14.0'))
        session.get.assert_called_once_with('https://example.invalid:8443/plugins/axlsqltoolkit.zip',stream=True,timeout=30)
        self.assertEqual(self.log.write.call_args.args[0],'toolkit_downloaded')
        self.assertEqual(len(self.log.write.call_args.kwargs['archive_sha256']),64)
        session.get.reset_mock()
        self.assertEqual(m.ensure_toolkit(None,self.cache,'14.0',session,self.endpoint,30,self.log),path)
        session.get.assert_not_called()
        self.assertFalse((self.cache/'15.0').exists())
        self.assertFalse(any(self.cache.rglob('*.exe')))

    def test_current_directory_selected_by_namespace(self):
        path,_=self.run_setup(archive([('schema/current/AXLAPI.wsdl',wsdl('15.0'))]),version='15.0')
        self.assertEqual(path,self.cache/'15.0'/'AXLAPI.wsdl')

    def test_explicit_wsdl_not_downloaded_or_replaced(self):
        file=Path(self.temp.name)/'manual.wsdl'; file.write_text('manual')
        session=Mock()
        self.assertEqual(m.ensure_toolkit(file,self.cache,'14.0',session,self.endpoint,30,self.log),file)
        with self.assertRaises(m.CheckError):
            m.ensure_toolkit(file.with_name('missing.wsdl'),self.cache,'14.0',session,self.endpoint,30,self.log)
        session.get.assert_not_called()
        self.assertEqual(file.read_text(),'manual')

    def test_incomplete_existing_cache_preserved(self):
        directory=self.cache/'14.0';directory.mkdir(parents=True)
        marker=directory/'keep'; marker.write_text('original')
        session=Mock()
        with self.assertRaises(m.CheckError): m.ensure_toolkit(None,self.cache,'14.0',session,self.endpoint,30,self.log)
        session.get.assert_not_called();self.assertEqual(marker.read_text(),'original')

    def test_html_denied_redirect_and_wrong_schema_fail_cleanly(self):
        for data,status in [(b'<html>login</html>',200),(b'',401),(b'',403),(b'',302),
                            (archive([('schema/15.0/AXLAPI.wsdl',wsdl('15.0'))]),200)]:
            with self.subTest(status=status),self.assertRaises(m.CheckError): self.run_setup(data,status=status)
            self.assert_clean()

    def test_unsafe_zip_paths_rejected(self):
        for name in ['../escape.xsd','/escape.xsd','C:/escape.xsd','schema\\escape.xsd',
                     'schema/CON.xsd','schema/test./escape.xsd']:
            with self.subTest(name=name),self.assertRaises(m.CheckError):
                self.run_setup(archive([(name,'bad')]))
            self.assert_clean()
        self.assertFalse((Path(self.temp.name)/'escape.xsd').exists())

    def test_zip_link_and_case_collision_rejected(self):
        link=zipfile.ZipInfo('schema/link.xsd');link.create_system=3
        link.external_attr=(stat.S_IFLNK|0o777)<<16
        for entries in [[(link,'../outside')],[('schema/a.xsd','one'),('schema/A.xsd','two')]]:
            with self.assertRaises(m.CheckError): self.run_setup(archive(entries))
            self.assert_clean()

    def test_download_and_extraction_limits(self):
        data=archive([('schema/14.0/AXLAPI.wsdl',wsdl('14.0'))])
        for constant in ('MAX_ZIP_BYTES','MAX_UNPACKED_BYTES','MAX_ZIP_ENTRIES'):
            with patch.object(m,constant,0),self.assertRaises(m.CheckError): self.run_setup(data)
            self.assert_clean()

    def test_invalid_wsdl_is_not_cached(self):
        with self.assertRaises(Exception):
            self.run_setup(archive([('schema/14.0/AXLAPI.wsdl','<invalid')]))
        self.assert_clean()

    def test_duplicate_matching_toolkits_rejected(self):
        with self.assertRaises(m.CheckError):
            self.run_setup(archive([('a/14.0/AXLAPI.wsdl',wsdl('14.0')),
                                    ('b/14.0/AXLAPI.wsdl',wsdl('14.0'))]))
        self.assert_clean()

    def test_remote_schema_import_not_cached(self):
        document=wsdl('14.0').replace('<types>','<import namespace="urn:external" location="https://other.invalid/remote.wsdl"/><types>')
        with self.assertRaises((m.CheckError, ExternalReferenceForbidden)):
            self.run_setup(archive([('schema/14.0/AXLAPI.wsdl',document)]))
        self.assert_clean()

    def test_transport_failure_cleans_staging_and_lock(self):
        session=Mock(verify=True,get=Mock(side_effect=m.requests.Timeout()))
        with contextlib.redirect_stdout(io.StringIO()),self.assertRaises(m.requests.Timeout):
            m.ensure_toolkit(None,self.cache,'14.0',session,self.endpoint,30,self.log)
        self.assert_clean()

    def test_companion_xsd_extracted_and_loaded(self):
        document=wsdl('14.0')
        match=re.search(r'<types>(.*?)</types>',document,re.S)
        xsd=match[1].replace('<x:schema ',f'<x:schema xmlns:x="http://www.w3.org/2001/XMLSchema" xmlns:a="{m.AXL}14.0" ',1)
        document=document[:match.start()]+f'<types><x:schema><x:import namespace="{m.AXL}14.0" schemaLocation="AXLSoap.xsd"/></x:schema></types>'+document[match.end():]
        path,_=self.run_setup(archive([('schema/14.0/AXLAPI.wsdl',document),('schema/14.0/AXLSoap.xsd',xsd)]))
        self.assertTrue((path.parent/'AXLSoap.xsd').is_file())
        with m.Session() as session:
            m.PhoneClient(session,self.endpoint,path,'14.0',30)

    def test_first_run_continues_to_dry_run_with_one_login(self):
        data=archive([('schema/14.0/AXLAPI.wsdl',wsdl('14.0'))])
        csvfile=Path(self.temp.name)/'one.csv'
        csvfile.write_text(f'device,destination,partition,new_label\n{DEVICE},4008,EXAMPLE_PT,New label\n')
        logfile=Path(self.temp.name)/'report.jsonl'
        session=m.Session()
        session.get=Mock(return_value=Response(data))
        xml=f'<s:Envelope xmlns:s="{m.SOAP}"><s:Body><a:getCCMVersionResponse xmlns:a="{m.AXL}14.0"><return><version>14.0.1</version></return></a:getCCMVersionResponse></s:Body></s:Envelope>'
        session.post=Mock(return_value=Mock(status_code=200,content=xml.encode()))
        with patch.object(m,'Session',return_value=session), \
             patch('builtins.input',return_value='fictional-user') as username, \
             patch.object(m.getpass,'getpass',return_value='fictional-password') as password, \
             patch.object(m.PhoneClient,'read',return_value=snapshot()), \
             patch.object(m.PhoneClient,'write') as write, \
             contextlib.redirect_stdout(io.StringIO()):
            result=m.main(['--cucm','example.invalid','--csv',str(csvfile),
                           '--schema-dir',str(self.cache),'--log',str(logfile)])
        self.assertEqual(result,0)
        username.assert_called_once(); password.assert_called_once()
        self.assertEqual(session.auth,('fictional-user','fictional-password'))
        session.get.assert_called_once(); write.assert_not_called()
        self.assertEqual(json.loads(logfile.read_text().splitlines()[-1])['event'],'dry_run_complete')

    def test_setup_lock_not_removed_if_owned_elsewhere(self):
        self.cache.mkdir();lock=self.cache/'.14.0.install-lock';lock.write_text('other')
        with self.assertRaises(m.CheckError):
            m.ensure_toolkit(None,self.cache,'14.0',Mock(),self.endpoint,30,self.log)
        self.assertEqual(lock.read_text(),'other')


if __name__=='__main__': unittest.main()
