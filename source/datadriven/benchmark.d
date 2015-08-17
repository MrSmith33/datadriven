module datadriven.benchmark;

import std.algorithm;
import core.time;
import std.datetime;
import std.stdio;
import std.conv : to;
import std.random;
import std.traits;
import std.typetuple;

enum entityCountMax = 1_000_000;
enum entityCountMed =   500_000;
enum entityCountMin =   100_000;
enum entityCount = 1000_000;
enum numRuns = 10;

void benchIteration()
{
	static struct Transform(T) {
		ulong id;
		T x, y, z;
	}

	static struct Velocity(T) {
		ulong id;
		T x, y, z;
	}

	auto tByte = new Transform!byte[entityCount];
	auto tShort = new Transform!short[entityCount];
	auto tInt = new Transform!int[entityCount];
	auto tLong = new Transform!long[entityCount];
	auto tFloat = new Transform!float[entityCount];
	auto tDouble = new Transform!double[entityCount];
	auto tReal = new Transform!real[entityCount];

	auto r = benchmark!(
			transformProcessor!tByte,
			transformProcessor!tShort,
			transformProcessor!tInt,
			transformProcessor!tLong,
			transformProcessor!tFloat,
			transformProcessor!tDouble,
			transformProcessor!tReal,
		)(numRuns);

	auto range = r[].map!(a => (to!Duration(a)/numRuns).durf);
	foreach(item; range)
		item.writeln;
}

void benchIteration2()
{
	static struct Transform {
		float x, y, z;
	}

	static struct Velocity1 {
		float x, y, z;
	}

	static struct Velocity2 {
		float x, y, z;
	}

	static struct Velocity3 {
		float x, y, z;
	}

	static struct Entity {
		Transform transform;
		Velocity1 velocity1;
		Velocity2 velocity2;
		Velocity3 velocity3;
	}

	Entity[] entities = new Entity[entityCount];

	foreach(ref e; entities) {
		e.velocity1 = Velocity1(1, 1, 1);
		e.velocity2 = Velocity2(1, 1, 1);
		e.velocity3 = Velocity3(1, 1, 1);
		e.transform = Transform(0, 0, 0);
	}

	StopWatch sw;
	sw.start();

	foreach(row; entities)
	{
		row.transform.x += row.velocity1.x * 2 + row.velocity2.x * 3 + row.velocity3.x * 4;
		row.transform.y += row.velocity1.y * 2 + row.velocity2.y * 3 + row.velocity3.y * 4;
		row.transform.z += row.velocity1.z * 2 + row.velocity2.z * 3 + row.velocity3.z * 4;
	}

	printBenchResult("AOS iteration %s", sw.peek);
}

void benchStupidSearchJoin()
{
	static struct Transform(T) {
		ulong id;
		T x, y, z;
	}

	static struct Velocity(T) {
		ulong id;
		T x, y, z;
	}

	auto transforms = new Transform!float[entityCount];
	auto velocities = new Velocity!float[entityCount];

	foreach(index; 0..entityCount)
	{
		transforms[index].id = index;
		velocities[index].id = index;
	}

	transforms.randomShuffle;
	velocities.randomShuffle;

	float dt = 0.5;
	// stupid search
	///////////////////////////////////////////////////////////////////////////
	StopWatch sw;
	sw.start();

	foreach(ref transform; transforms)
	{
		auto found = find!(a => a.id == transform.id)(velocities);
		if (found.length)
		{
			transform.x += dt * found[0].x;
			transform.y += dt * found[0].y;
			transform.z += dt * found[0].z;
		}
	}

	printBenchResult("stupid search %s", sw.peek);
}

void benchBinarySearchJoin()
{
	static struct Transform(T) {
		ulong id;
		T x, y, z;
	}

	static struct Velocity(T) {
		ulong id;
		T x, y, z;
	}

	auto transforms = new Transform!float[entityCount];
	auto velocities = new Velocity!float[entityCount];
	StopWatch sw;
	float dt = 0.5;

	foreach(index; 0..entityCount)
	{
		transforms[index].id = index;
		velocities[index].id = index;
	}

	transforms.randomShuffle;
	velocities.randomShuffle;

	// sort + binary search
	///////////////////////////////////////////////////////////////////////////
	sw.start();

	auto sortedVelocities = sort!("a.id < b.id")(velocities);

	sw.stop();
	printBenchResult("SORTING %s", sw.peek);
	sw.start();

	foreach(ref transform; transforms)
	{
		auto found = sortedVelocities.trisect(transform);
		if (found[1].length)
		{
			transform.x += dt * found[1][0].x;
			transform.y += dt * found[1][0].y;
			transform.z += dt * found[1][0].z;
		}
	}

	printBenchResult("binary search %s", sw.peek);
}

void benchBinarySearchJoinFull()
{
	static struct Transform(T) {
		ulong id;
		T x, y, z;
	}

	static struct Velocity(T) {
		ulong id;
		T x, y, z;
	}

	auto transforms = new Transform!float[entityCount];
	auto velocities = new Velocity!float[entityCount];
	StopWatch sw;
	float dt = 0.5;

	foreach(index; 0..entityCount)
	{
		transforms[index].id = index;
		velocities[index].id = index;
	}

	transforms.randomShuffle;
	velocities.randomShuffle;

	// sort both tables + binary search
	///////////////////////////////////////////////////////////////////////////
	velocities.randomShuffle;
	sw.reset();

	auto sortedVelocities = sort!("a.id < b.id")(velocities);
	auto sortedTransforms = sort!("a.id < b.id")(transforms);

	sw.stop();
	printBenchResult("SORTING both %s", sw.peek);
	sw.start();

	foreach(ref transform; sortedTransforms)
	{
		auto found = sortedVelocities.trisect(transform);
		if (found[1].length)
		{
			transform.x += dt * found[1][0].x;
			transform.y += dt * found[1][0].y;
			transform.z += dt * found[1][0].z;
		}
	}

	printBenchResult("binary search %s", sw.peek);
}

void benchApiJoinBalanced()
{
	import datadriven.api;
	import datadriven.storage;
	import datadriven.components;

	HashmapComponentStorage!Transform transformStorage;
	HashmapComponentStorage!Velocity velocityStorage;

	foreach(index; 0..entityCount)
	{
		transformStorage.add(EntityId(index), Transform(0, 0, 0));
		velocityStorage.add(EntityId(index), Velocity(1, 1, 1));
	}

	auto query = componentQuery(transformStorage, velocityStorage);

	StopWatch sw;
	sw.start();

	foreach(row; query)
	{
		row.transform.x += row.velocity.x;
		row.transform.y += row.velocity.y;
		row.transform.z += row.velocity.z;
	}

	printBenchResult("Api hash join %s", sw.peek);
}

void benchApiJoinBalanced2()
{
	import datadriven.api;
	import datadriven.storage;
	import datadriven.components;

	static struct Velocity1 {
		float x, y, z;
	}

	static struct Velocity2 {
		float x, y, z;
	}

	static struct Velocity3 {
		float x, y, z;
	}

	static struct Transform {
		float x, y, z;
	}

	HashmapComponentStorage!Transform transformStorage;
	HashmapComponentStorage!Velocity1 velocity1Storage;
	HashmapComponentStorage!Velocity2 velocity2Storage;
	HashmapComponentStorage!Velocity3 velocity3Storage;

	foreach(index; 0..entityCountMin) {
		velocity1Storage.add(EntityId(index), Velocity1(1, 1, 1));
		velocity2Storage.add(EntityId(index), Velocity2(1, 1, 1));
		velocity3Storage.add(EntityId(index), Velocity3(1, 1, 1));
	}
	foreach(index; 0..entityCountMax) {
		transformStorage.add(EntityId(index), Transform(0, 0, 0));
	}
	//foreach(index; 0..entityCountMax) {
	//	transformStorage.add(EntityId(index), Transform(0, 0, 0));
	//	velocityStorage.add(EntityId(index), Velocity(1, 1, 1));
	//}

	auto query = componentQuery(transformStorage, velocity1Storage, velocity2Storage, velocity3Storage);

	StopWatch sw;
	sw.start();

	foreach(row; query)
	{
		row.transform.x += row.velocity1.x * 2 + row.velocity2.x * 3 + row.velocity3.x * 4;
		row.transform.y += row.velocity1.y * 2 + row.velocity2.y * 3 + row.velocity3.y * 4;
		row.transform.z += row.velocity1.z * 2 + row.velocity2.z * 3 + row.velocity3.z * 4;
	}

	printBenchResult("Api hash join 4 %s", sw.peek);
}

void printBenchResult(string formatting, TickDuration dur)
{
	writefln(formatting, (cast(Duration)dur).formatDuration);
}

alias durf = formatDuration;
auto formatDuration(Duration dur)
{
	import std.string : format;
	auto splitted = dur.split();
	return format("%s.%03s,%03s secs",
		splitted.seconds, splitted.msecs, splitted.usecs);
}

void transformProcessor(alias transforms)()
{
	foreach(ref transform; transforms)
	{
		transform.x = transform.y / 2 + 4;
		transform.y = transform.z / 2 + 4;
		transform.z = transform.x / 2 + 4;
	}
}