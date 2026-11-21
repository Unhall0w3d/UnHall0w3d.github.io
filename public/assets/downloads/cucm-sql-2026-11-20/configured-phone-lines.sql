select d.name as DeviceName,
       d.description as DeviceDescription,
       n.dnorpattern as Extension,
       rp.name as Partition,
       vmp.name as VoiceMailProfile
from device d
inner join devicenumplanmap dnpm on dnpm.fkdevice=d.pkid
inner join numplan n on n.pkid=dnpm.fknumplan
left join routepartition rp on rp.pkid=n.fkroutepartition
left join voicemessagingprofile vmp on vmp.pkid=n.fkvoicemessagingprofile
where d.tkclass=1 and n.tkpatternusage=2
order by n.dnorpattern,d.name
