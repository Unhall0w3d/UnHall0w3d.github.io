select 'SD' as entrytype,
       d.name,
       d.description,
       s.speeddialindex as buttonindex,
       s.label,
       s.speeddialnumber as destination,
       '' as partitionname
from speeddial s
inner join device d on s.fkdevice=d.pkid
where s.speeddialnumber='<EXTENSION>'
union all
select 'BLF' as entrytype,
       d.name,
       d.description,
       b.blfindex as buttonindex,
       b.label,
       case when b.blfdestination is null or b.blfdestination=''
            then n.dnorpattern else b.blfdestination end as destination,
       r.name as partitionname
from blfspeeddial b
inner join device d on b.fkdevice=d.pkid
left outer join numplan n on b.fknumplan=n.pkid
left outer join routepartition r on n.fkroutepartition=r.pkid
where b.blfdestination='<EXTENSION>' or n.dnorpattern='<EXTENSION>'
order by 1,2,4
