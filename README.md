# isp_static_routes
A bunch of old internet routes from Belwue, Switch and Tiscali route servers converted to statics for Junos.  This has the original communities and AS Paths added to the static routes.  

The files are all Junos {} format config files that will load up into a group, which can then be applied.  Simply copy these files onto a Junos box, do a load merge <filename>, apply the group in the location of you're choice and you've got a ton of static routes to inject into your lab.
  
The files with the .small, are a reduced set of routes in case you don't want the whole table from that ISP back in 2012.
  
The bgp2static.sh is an old bash script from 2012 that will take the saved output of a IOS or Quagga route servers "show ip bgp" and convert it into Junos set statements to recreate the route on Junos.
  
Don't use these for evil, and no-guarantees.
