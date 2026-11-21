select d.name as Device,
       d.description as Description,
       ln.dnorpattern as Extension,
       dcss.name as DeviceCSS,
       lcss.name as LineCSS,
       rp.dnorpattern as RoutePattern,
       rppt.name as RoutePatternPT,
       rp.authorizationlevelrequired as AuthorizationLevel
from device d
inner join devicenumplanmap dnpm on dnpm.fkdevice=d.pkid and dnpm.numplanindex=1
inner join numplan ln on ln.pkid=dnpm.fknumplan
left outer join callingsearchspace dcss on dcss.pkid=d.fkcallingsearchspace
left outer join callingsearchspace lcss on lcss.pkid=ln.fkcallingsearchspace_sharedlineappear
inner join numplan rp on rp.dnorpattern='<ROUTE_PATTERN>' and rp.tkpatternusage=5
inner join routepartition rppt on rppt.pkid=rp.fkroutepartition and rppt.name='<ROUTE_PARTITION>'
where d.tkclass=1
  and ((d.fkcallingsearchspace is not null and exists (
          select csm.pkid
          from callingsearchspacemember csm
          where csm.fkcallingsearchspace=d.fkcallingsearchspace
            and csm.fkroutepartition=rp.fkroutepartition))
       or (ln.fkcallingsearchspace_sharedlineappear is not null and exists (
          select csm2.pkid
          from callingsearchspacemember csm2
          where csm2.fkcallingsearchspace=ln.fkcallingsearchspace_sharedlineappear
            and csm2.fkroutepartition=rp.fkroutepartition)))
order by d.name
