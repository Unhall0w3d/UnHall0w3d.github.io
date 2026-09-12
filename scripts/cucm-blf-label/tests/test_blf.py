import contextlib
from copy import deepcopy
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import warnings
from unittest.mock import Mock, patch

SOURCE = Path(__file__).resolve().parents[1] / 'blf-label-update.py'
spec = importlib.util.spec_from_file_location('blf_update', SOURCE)
m = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = m
spec.loader.exec_module(m)

DEVICE = 'SEP020000000001'
UID = '00112233-4455-6677-8899-aabbccddeeff'


def snapshot():
    blfs = [dict(index=i, label=f'Label {i}', asciiLabel=f'ASCII {i}',
                 blfDirn=str(4000+i), routePartition='EXAMPLE_PT', blfDest='',
                 associatedBlfSdFeatures={'feature':['Pickup']}) for i in (1, 3, 8)]
    blfs[0]['blfDest'], blfs[0]['blfDirn'], blfs[0]['routePartition'] = '5550001', '', ''
    return dict(device=DEVICE, uuid=UID, blfs=blfs,
                raw_blfs={'busyLampField':deepcopy(blfs)},
                speeddials={'speeddial':[{'index':1,'dirn':'5550100','label':'Regular'}]},
                blfDirectedCallParks={'blfDirectedCallPark':[]})


def target(index=8, label='New label'):
    return dict(device=DEVICE, destination=str(4000+index), partition='EXAMPLE_PT',
                new_label=label, buttonindex=index, line_number=2)


def wsdl(version):
    # Deliberately minimal synthetic schema: exercises real Zeep, not Cisco qualification.
    return f'''<definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
+ xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:x="http://www.w3.org/2001/XMLSchema"
+ xmlns:a="{m.AXL}{version}" xmlns:t="http://www.cisco.com/AXLAPIService/"
+ targetNamespace="http://www.cisco.com/AXLAPIService/">
+ <types><x:schema targetNamespace="{m.AXL}{version}" elementFormDefault="unqualified">
+ <x:complexType name="XBusyLampField"><x:sequence>
+ <x:element name="blfDest" type="x:string"/>
+ <x:element name="blfDirn" type="x:string" minOccurs="0"/>
+ <x:element name="routePartition" type="x:string" minOccurs="0"/>
+ <x:element name="label" type="x:string" minOccurs="0"/>
+ <x:element name="asciiLabel" type="x:string" minOccurs="0"/>
+ <x:element name="associatedBlfSdFeatures" minOccurs="0"><x:complexType><x:sequence>
+ <x:element name="feature" type="x:string" minOccurs="0" maxOccurs="unbounded"/>
+ </x:sequence></x:complexType></x:element>
+ <x:element name="index" type="x:positiveInteger"/>
+ </x:sequence></x:complexType>
+ <x:element name="updatePhone"><x:complexType><x:sequence>
+ <x:element name="uuid" type="x:string"/>
+ <x:element name="busyLampFields"><x:complexType><x:sequence>
+ <x:element name="busyLampField" type="a:XBusyLampField" maxOccurs="unbounded"/>
+ </x:sequence></x:complexType></x:element>
+ </x:sequence></x:complexType></x:element>
+ <x:element name="updatePhoneResponse" type="x:string"/>
+ </x:schema></types>
+ <message name="request"><part name="parameters" element="a:updatePhone"/></message>
+ <message name="response"><part name="parameters" element="a:updatePhoneResponse"/></message>
+ <portType name="AXLPort"><operation name="updatePhone"><input message="t:request"/><output message="t:response"/></operation></portType>
+ <binding name="AXLAPIBinding" type="t:AXLPort"><soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
+ <operation name="updatePhone"><soap:operation soapAction="CUCM:DB ver={version} updatePhone"/>
+ <input><soap:body use="literal"/></input><output><soap:body use="literal"/></output></operation></binding>
+ <service name="AXLAPIService"><port name="AXLPort" binding="t:AXLAPIBinding"><soap:address location="https://example.invalid/axl/"/></port></service>
+ </definitions>'''.replace('\n+', '\n')


class Tests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)

    def execute(self, client, apply=True, groups=None, journal=None):
        own = journal is None
        journal = journal or m.Journal(self.path/'run.jsonl')
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                code = m.run(client, groups or {DEVICE:[target()]}, journal, apply)
        finally:
            if own: journal.close()
        events = [json.loads(line) for line in (self.path/'run.jsonl').read_text().splitlines()] if own else []
        return code, events

    def test_label_only_full_collection(self):
        before = snapshot()
        after, changes = m.prepare(before,[target()])
        self.assertEqual([b['index'] for b in after],[1,3,8])
        self.assertEqual(after[:2],before['blfs'][:2])
        self.assertEqual(after[2],{**before['blfs'][2],'label':'New label'})
        self.assertEqual(before,snapshot())
        self.assertEqual(changes[0]['status'],'update_needed')

    def test_multiple_edits_one_phone(self):
        before = snapshot()
        desired,_ = m.prepare(before,[target(3),target(8)])
        after = {**before,'blfs':desired}
        client = Mock(read=Mock(side_effect=[before,before,after]))
        code,_=self.execute(client,groups={DEVICE:[target(3),target(8)]})
        self.assertEqual(code,0)
        client.write.assert_called_once_with(UID,desired)

    def test_full_pre_post_logged(self):
        before=snapshot(); desired,_=m.prepare(before,[target()]); after={**before,'blfs':desired}
        client=Mock(read=Mock(side_effect=[before,before,after]))
        def write(*args):
            records=[json.loads(s) for s in (self.path/'run.jsonl').read_text().splitlines()]
            self.assertEqual(records[-1]['event'],'write_intent')
            self.assertEqual(len(records[-1]['before']['blfs']),3)
        client.write.side_effect=write
        code,events=self.execute(client)
        self.assertEqual(code,0)
        self.assertEqual(next(e for e in events if e['event']=='precheck')['snapshot'],before)
        self.assertEqual(next(e for e in events if e['event']=='postcheck')['snapshot'],after)

    def test_server_retains_only_target_is_detected_and_logged(self):
        before=snapshot(); after=deepcopy(before); after['blfs']=[{**before['blfs'][2],'label':'New label'}]
        client=Mock(read=Mock(side_effect=[before,before,after]))
        code,events=self.execute(client)
        self.assertEqual(code,1)
        self.assertEqual(events[-1]['event'],'verification_failed')
        self.assertEqual(len(events[-2]['snapshot']['blfs']),1)

    def test_unrelated_change_detected(self):
        for field in ['blfs','speeddials','blfDirectedCallParks']:
            with self.subTest(field=field):
                before=snapshot(); desired,_=m.prepare(before,[target()]); after={**deepcopy(before),'blfs':desired}
                if field=='blfs': after[field][0]['label']='Unexpected'
                else: after[field]={'changed':True}
                client=Mock(read=Mock(side_effect=[before,before,after]))
                journal=Mock()
                code,_=self.execute(client,journal=journal)
                self.assertEqual(code,1)
                self.assertEqual(journal.write.call_args.args[0],'verification_failed')

    def test_drift_blocks_write(self):
        before=snapshot(); fresh=deepcopy(before); fresh['blfs'][0]['label']='Other admin'
        client=Mock(read=Mock(side_effect=[before,fresh]))
        code,_=self.execute(client)
        self.assertEqual(code,1); client.write.assert_not_called()

    def test_preflight_failure_blocks_all_writes(self):
        client=Mock(read=Mock(side_effect=[snapshot(),m.CheckError('missing')]))
        code,_=self.execute(client,groups={DEVICE:[target()], 'SEP020000000002':[target()]})
        self.assertEqual(code,1); client.write.assert_not_called()

    def test_dry_run(self):
        client=Mock(read=Mock(return_value=snapshot()))
        code,_=self.execute(client,apply=False)
        self.assertEqual(code,0); client.write.assert_not_called()

    def test_already_ok(self):
        before=snapshot(); before['blfs'][2]['label']='New label'
        client=Mock(read=Mock(return_value=before))
        code,events=self.execute(client)
        self.assertEqual(code,0); client.write.assert_not_called()
        self.assertIn('already_ok',[e['event'] for e in events])

    def test_write_timeout_no_retry(self):
        client=Mock(read=Mock(return_value=snapshot()),write=Mock(side_effect=m.requests.Timeout('sensitive')))
        code,events=self.execute(client)
        self.assertEqual(code,1); client.write.assert_called_once()
        self.assertEqual(events[-1]['event'],'uncertain'); self.assertEqual(events[-1]['reason'],'Timeout')

    def test_log_error_before_write(self):
        client=Mock(read=Mock(return_value=snapshot())); journal=Mock()
        def log(event,**kwargs):
            if event=='write_intent': raise OSError('full')
        journal.write.side_effect=log
        with self.assertRaises(OSError): self.execute(client,journal=journal)
        client.write.assert_not_called()

    def test_log_error_after_write_stops(self):
        before=snapshot(); desired,_=m.prepare(before,[target()]); after={**before,'blfs':desired}
        client=Mock(read=Mock(side_effect=[before,before,after])); journal=Mock()
        def log(event,**kwargs):
            if event=='postcheck': raise OSError('full')
        journal.write.side_effect=log
        with self.assertRaises(OSError): self.execute(client,journal=journal)
        client.write.assert_called_once()

    def test_input_and_conflicts(self):
        file=self.path/'list.csv'
        header='device,destination,partition,new_label\n'
        row=f'{DEVICE},4008,EXAMPLE_PT,New label\n'
        for content in [header,header+row+row,header+f'{DEVICE},4008,EXAMPLE_PT\n',
                        'device,destination,partition,new_label,new_label\n',
                        header+f'bad,4008,EXAMPLE_PT,New\n']:
            file.write_text(content)
            with self.subTest(content=content),self.assertRaises(m.CheckError): m.load_updates(file)
        file.write_text(header+f'{DEVICE},004008,,New\n')
        self.assertEqual(m.load_updates(file)[DEVICE][0]['destination'],'004008')
        with self.assertRaises(m.CheckError): m.prepare(snapshot(),[target(),target()])

    def test_ambiguous_and_free_form_not_selected(self):
        before=snapshot(); before['blfs'][0]['blfDest']='4008'
        desired,_=m.prepare(before,[target()])
        self.assertEqual(desired[0],before['blfs'][0])
        before['blfs'][1].update(blfDirn='4008')
        t=target(); t['buttonindex']=None
        with self.assertRaises(m.CheckError): m.prepare(before,[t])
        before['blfs']=before['blfs'][:1]
        with self.assertRaises(m.CheckError): m.prepare(before,[t])

    def test_canonical_rejects_lossy_fields(self):
        for modification in [{'unknown':'valuable'},{'index':None},{'blfDirn':'conflict'}]:
            raw=deepcopy(snapshot()['raw_blfs']); raw['busyLampField'][0].update(modification)
            with self.assertRaises(m.CheckError): m.canonical_blfs(raw)

    def test_discovery_uses_accepted_schema_not_software_major(self):
        xml=f'<s:Envelope xmlns:s="{m.SOAP}"><s:Body><a:getCCMVersionResponse xmlns:a="{m.AXL}14.0"><return><componentVersion><version>15.0.1.10000-1</version></componentVersion></return></a:getCCMVersionResponse></s:Body></s:Envelope>'
        session=Mock(post=Mock(return_value=Mock(status_code=200,content=xml.encode())))
        version,software,_=m.negotiate(session,'https://example.invalid:8443/axl/',30)
        self.assertEqual(version,'14.0'); self.assertTrue(software.startswith('15.'))
        session.post.assert_called_once()

    def test_discovery_server_advertised_retry(self):
        bad=Mock(status_code=599,text='Incorrect AXL version. Supported axl versions are 15.x')
        xml=f'<s:Envelope xmlns:s="{m.SOAP}"><s:Body><a:getCCMVersionResponse xmlns:a="{m.AXL}15.0"><return><version>15.0.1</version></return></a:getCCMVersionResponse></s:Body></s:Envelope>'
        session=Mock(post=Mock(side_effect=[bad,Mock(status_code=200,content=xml.encode())]))
        self.assertEqual(m.negotiate(session,'https://example.invalid/axl/',30)[0],'15.0')
        self.assertEqual(session.post.call_count,2)
        self.assertIn('ver=15.0',session.post.call_args.kwargs['headers']['SOAPAction'])

    def test_discovery_no_retry_on_other_errors(self):
        for response in [Mock(status_code=401,text='Incorrect AXL version Supported axl versions are 15.x'),
                         Mock(status_code=500,text='server failed'),Mock(status_code=200,content=b'bad'),
                         Mock(status_code=599,text='Incorrect AXL version. Supported axl versions are 12.5')]:
            session=Mock(post=Mock(return_value=response))
            with self.assertRaises(m.CheckError): m.negotiate(session,'https://example.invalid/axl/',30)
            session.post.assert_called_once()
        session=Mock(post=Mock(side_effect=m.requests.Timeout()))
        with self.assertRaises(m.requests.Timeout): m.negotiate(session,'https://example.invalid/axl/',30)
        session.post.assert_called_once()

    def test_actual_zeep_serialization_preserves_every_entry(self):
        for version in m.SUPPORTED:
            file=self.path/'AXLAPI.wsdl'; file.write_text(wsdl(version))
            with m.Session() as session:
                client=m.PhoneClient(session,'https://example.invalid/axl/',file,version,30)
                desired,_=m.prepare(snapshot(),[target()])
                client.validate_payload(UID,desired)
                message=client.client.create_message(client.service,'updatePhone',uuid=UID,busyLampFields=client.payload(desired))
                fields=[e for e in message.iter() if m.local(e.tag)=='busyLampField']
                self.assertEqual(len(fields),3)
                self.assertEqual([next(c.text for c in e if m.local(c.tag)=='index') for e in fields],['1','3','8'])
                self.assertEqual([m.local(e.tag) for e in fields[2]].count('blfDest'),0)
                self.assertEqual(next(e.text for e in fields[2] if m.local(e.tag)=='asciiLabel'),'ASCII 8')

    def test_serialized_omission_or_duplicate_rejected(self):
        file=self.path/'AXLAPI.wsdl'; file.write_text(wsdl('14.0'))
        with m.Session() as session:
            client=m.PhoneClient(session,'https://example.invalid/axl/',file,'14.0',30)
            desired,_=m.prepare(snapshot(),[target()])
            original=client.payload
            for short in (True,False):
                def bad_payload(blfs):
                    payload=original(blfs)
                    entries=payload['busyLampField']
                    if short: entries.pop(0)
                    else: entries[0]=deepcopy(entries[1])
                    return payload
                client.payload=bad_payload
                with self.assertRaises(m.CheckError): client.validate_payload(UID,desired)

    def test_interrupted_write_is_uncertain(self):
        client=Mock(read=Mock(return_value=snapshot()),write=Mock(side_effect=KeyboardInterrupt()))
        code,events=self.execute(client)
        self.assertEqual(code,1)
        self.assertEqual(events[-1]['event'],'uncertain')
        client.write.assert_called_once()

    def test_real_zeep_value_serialized_before_dict_access(self):
        compound=m.xsd.ComplexType([m.xsd.Element('name',m.xsd.String()),m.xsd.Element('uuid',m.xsd.String()),
                                    m.xsd.Element('busyLampFields',m.xsd.AnyType())])
        phone=compound(name=DEVICE,uuid=UID,busyLampFields=snapshot()['raw_blfs'])
        client=m.PhoneClient.__new__(m.PhoneClient)
        client.service=Mock(getPhone=Mock(return_value={'return':{'phone':phone}}))
        self.assertEqual(client.read(DEVICE)['blfs'],snapshot()['blfs'])

    def test_toolkit_mismatch_and_remote_import_blocked(self):
        file=self.path/'AXLAPI.wsdl'; file.write_text(wsdl('15.0'))
        with m.Session() as session:
            with self.assertRaises(Exception): m.PhoneClient(session,'https://example.invalid/axl/',file,'14.0',30)
        transport=m.LocalTransport(self.path)
        with self.assertRaises(m.CheckError): transport.load('https://example.invalid/schema.xsd')
        with self.assertRaises(m.CheckError): transport.load(str(self.path.parent/'outside.xsd'))

    def test_insecure_excludes_ca_file(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
            m.main(['--cucm','example.invalid','--username','test','--csv','unused.csv',
                    '--insecure','--ca-file','unused.pem'])
        self.assertEqual(raised.exception.code,2)

    def test_tls_choice_logged_and_used_for_discovery(self):
        csvfile=self.path/'input.csv'
        csvfile.write_text(f'device,destination,partition,new_label\n{DEVICE},4008,EXAMPLE_PT,New\n')
        for insecure in (False,True):
            logfile=self.path/f'run-{insecure}.jsonl'
            def discovery(session,*args):
                self.assertIs(session.verify,not insecure)
                raise m.CheckError('End of mocked discovery')
            stderr=io.StringIO()
            with patch.object(m.getpass,'getpass',return_value='fictional'), \
                 patch.object(m,'negotiate',side_effect=discovery), \
                 contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(stderr):
                result=m.main(['--cucm','example.invalid','--username','test','--csv',str(csvfile),
                               '--log',str(logfile)]+(['--insecure'] if insecure else []))
            self.assertEqual(result,2)
            first=json.loads(logfile.read_text().splitlines()[0])
            self.assertIs(first['tls_verification'],not insecure)
            self.assertEqual('WARNING: --insecure' in stderr.getvalue(),insecure)

    def test_insecure_explicit_on_each_request(self):
        with m.Session() as session, patch.object(m.requests.Session,'request',return_value=Mock(status_code=200)) as request:
            session.verify=False
            session.post('https://example.invalid/axl/')
            self.assertIs(request.call_args.kwargs['verify'],False)
            self.assertIs(request.call_args.kwargs['allow_redirects'],False)

    def test_insecure_suppresses_only_repeated_tls_warning(self):
        def request(*args,**kwargs):
            warnings.warn('Unverified HTTPS request',m.InsecureRequestWarning)
            warnings.warn('Unrelated warning',UserWarning)
            return Mock(status_code=200)
        for verify in (True,False):
            with m.Session() as session, patch.object(m.requests.Session,'request',side_effect=request), \
                 warnings.catch_warnings(record=True) as seen:
                warnings.simplefilter('always')
                session.verify=verify
                session.post('https://example.invalid/axl/')
                categories=[w.category for w in seen]
                self.assertIn(UserWarning,categories)
                self.assertEqual(m.InsecureRequestWarning in categories,verify)
                # Request-scoped suppression must not change later warning handling.
                warnings.warn('Outside request',m.InsecureRequestWarning)
                self.assertEqual(seen[-1].category,m.InsecureRequestWarning)

    def test_journal_no_overwrite(self):
        file=self.path/'audit.jsonl'; file.write_text('keep')
        with self.assertRaises(FileExistsError): m.Journal(file)
        self.assertEqual(file.read_text(),'keep')


if __name__=='__main__': unittest.main()
