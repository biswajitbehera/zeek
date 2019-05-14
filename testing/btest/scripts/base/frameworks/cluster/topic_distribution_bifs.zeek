# @TEST-PORT: BROKER_PORT1
# @TEST-PORT: BROKER_PORT2
# @TEST-PORT: BROKER_PORT3
# @TEST-PORT: BROKER_PORT4
# @TEST-PORT: BROKER_PORT5
#
# @TEST-EXEC: btest-bg-run manager-1 BROPATH=$BROPATH:.. CLUSTER_NODE=manager-1 zeek %INPUT
# @TEST-EXEC: btest-bg-run proxy-1   BROPATH=$BROPATH:.. CLUSTER_NODE=proxy-1 zeek %INPUT
# @TEST-EXEC: btest-bg-run proxy-2   BROPATH=$BROPATH:.. CLUSTER_NODE=proxy-2 zeek %INPUT
# @TEST-EXEC: btest-bg-wait 30
# @TEST-EXEC: btest-diff manager-1/.stdout
# @TEST-EXEC: btest-diff proxy-1/.stdout
# @TEST-EXEC: btest-diff proxy-2/.stdout

@TEST-START-FILE cluster-layout.zeek
redef Cluster::nodes = {
	["manager-1"] = [$node_type=Cluster::MANAGER, $ip=127.0.0.1, $p=to_port(getenv("BROKER_PORT1"))],
	["proxy-1"] = [$node_type=Cluster::PROXY,     $ip=127.0.0.1, $p=to_port(getenv("BROKER_PORT2")), $manager="manager-1"],
	["proxy-2"] = [$node_type=Cluster::PROXY,     $ip=127.0.0.1, $p=to_port(getenv("BROKER_PORT3")), $manager="manager-1"],
	["worker-1"] = [$node_type=Cluster::WORKER,   $ip=127.0.0.1, $p=to_port(getenv("BROKER_PORT4")), $manager="manager-1", $interface="eth0"],
	["worker-2"] = [$node_type=Cluster::WORKER,   $ip=127.0.0.1, $p=to_port(getenv("BROKER_PORT5")), $manager="manager-1", $interface="eth1"],
};
@TEST-END-FILE

global proxy_count = 0;
global q = 0;

event go_away()
	{
	terminate();
	}

event distributed_event_hrw(c: count)
	{
	print "got distributed event hrw", c;
	}

event distributed_event_rr(c: count)
	{
	print "got distributed event rr", c;
	}

function send_stuff(heading: string)
	{
	print heading;

	local v: vector of count = vector(0, 1, 2, 3, 13, 37, 42, 101);

	for ( i in v )
		print "hrw", v[i], Cluster::publish_hrw(Cluster::proxy_pool, v[i],
												distributed_event_hrw, v[i]);

	local rr_key = "test";

	for ( i in v )
		print "rr", Cluster::publish_rr(Cluster::proxy_pool, rr_key,
										distributed_event_rr, v[i]);
	}

event Cluster::node_up(name: string, id: string)
	{
	if ( Cluster::node != "manager-1" )
		return;

	if ( name == "proxy-1" || name == "proxy-2" )
		++proxy_count;

	if ( proxy_count == 2 )	
		{
		send_stuff("1st stuff");
		local e = Broker::make_event(go_away);
		Broker::publish(Cluster::node_topic("proxy-1"), e);
		}
	}

event Cluster::node_down(name: string, id: string)
	{
	if ( Cluster::node != "manager-1" )
		return;

	if ( name == "proxy-1" )
		{
		send_stuff("2nd stuff");
		local e = Broker::make_event(go_away);
		Broker::publish(Cluster::node_topic("proxy-2"), e);
		}

	if ( name == "proxy-2" )
		{
		send_stuff("no stuff");
		terminate();
		}
	}

event Cluster::node_down(name: string, id: string)
	{
	if ( name == "manager-1" )
		terminate();
	}
