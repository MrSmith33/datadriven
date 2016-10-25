module datadriven.main;

import core.time;
import std.algorithm;
import std.conv : to;
import std.datetime;
import std.random;
import std.stdio;
import std.typetuple;

import datadriven.api;
import datadriven.benchmark;
import datadriven.components;
import datadriven.storage;
import datadriven.entityman;

import voxelman.container.buffer;
import voxelman.world.storage.iomanager;

void main()
{
	/*
	writeln("BENCH ITERATION");
	//benchIteration();
	benchIteration2();
	benchIteration4();
	writeln("BENCH JOIN");
	//benchBinarySearchJoin();
	//benchBinarySearchJoinFull();
	benchApiFullJoin2!HashmapComponentStorage();
	benchApiFullJoin2!CustomHashmapComponentStorage();
	benchApiFullJoin4!HashmapComponentStorage();
	benchApiFullJoin4!CustomHashmapComponentStorage();
	benchApiPartialJoin!HashmapComponentStorage();
	benchApiPartialJoin!CustomHashmapComponentStorage();
	benchApiPartialJoinEman!CustomHashmapComponentStorage();
	benchApiPartialJoinSet();
	benchApiPartialJoinOnlySet();
	*/
	testEntityManager();
}

void testEntityManager()
{
	EntityManager eman;

	eman.registerComponent!Transform("transform");
	eman.registerComponent!Velocity("velocity");

	eman.add(0, Transform(0, 0, 0), Velocity(10, 10, 10));
	eman.add(1, Transform(1, 1, 1), Velocity(10, 10, 10));
	eman.add(2, Transform(2, 2, 2), Velocity(10, 10, 10));

	assert(*eman.get!Transform(0) == Transform(0,0,0));
	assert(*eman.get!Velocity(0) == Velocity(10, 10, 10));

	//writefln("%s", *eman.get!Transform(0));
	//writefln("%s", *eman.get!Velocity(0));

	///////////////////////////////////////////////////////////////
	// test query
	auto query = eman.query!(Transform, Velocity);

	void printEntities()
	{
		foreach(row; query)
			writefln("%s %s %s",
				row.id,
				*row.transform_0,
				*row.velocity_1);
	}

	writefln("After add");
	printEntities();

	eman.remove(0);

	assert(eman.get!Transform(0) is null);
	assert(eman.get!Velocity(0) is null);

	//writefln("%s", eman.get!Transform(0));
	//writefln("%s", eman.get!Velocity(0));

	///////////////////////////////////////////////////////////////
	// test save/load

	StringMap stringMap;
	PluginDataSaver saver;
	PluginDataLoader loader;
	FakeDb db;
	saver.stringMap = &stringMap;
	loader.stringMap = &stringMap;
	loader.getter = &db.getter;

	// save
	eman.save(saver);

	db.populate(saver);
	eman.removeAll();

	writefln("After removeAll");
	printEntities();

	// load
	eman.load(loader);

	writefln("After load");
	printEntities();
}

struct FakeDb
{
	ubyte[][ubyte[16]] entries;
	void populate(ref PluginDataSaver saver)
	{
		foreach(ubyte[16] key, ubyte[] data; saver) {
			entries[key] = data.dup;
		}
		saver.reset();
	}

	ubyte[] getter(ubyte[16] key)
	{
		return entries.get(key, null);
	}
}
