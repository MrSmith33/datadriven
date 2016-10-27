module datadriven.benchmark;

import std.algorithm;
import core.time;
import std.datetime;
import std.stdio;
import std.conv : to;
import std.random;
import std.traits;
import std.typetuple;

import datadriven.api;
import datadriven.storage;
import datadriven.components;
import datadriven.query;
import datadriven.entityman;

enum entityCountMax = 1_000_000;
enum entityCountMed =   500_000;
enum entityCountMin =   100_000;
enum entityCount = 1_000_000;
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
	static struct Entity {
		Transform transform;
		Velocity velocity;
	}

	Entity[] entities = new Entity[entityCount];

	foreach(ref e; entities) {
		e.velocity = Velocity(1, 1, 1);
		e.transform = Transform(0, 0, 0);
	}

	StopWatch sw;
	sw.start();

	foreach(i, ref row; entities)
	{
		row.transform.x += row.velocity.x * 2;
		row.transform.y += row.velocity.y * 2;
		row.transform.z += row.velocity.z * 2;
	}

	printBenchResult("%s : AOS iteration, 2 components", sw.peek);
}

void benchIteration4()
{
	static struct Entity {
		Transform transform;
		Velocity velocity1;
		Velocity velocity2;
		Velocity velocity3;
	}

	Entity[] entities = new Entity[entityCount];

	foreach(ref e; entities) {
		e.velocity1 = Velocity(1, 1, 1);
		e.velocity2 = Velocity(1, 1, 1);
		e.velocity3 = Velocity(1, 1, 1);
		e.transform = Transform(0, 0, 0);
	}

	StopWatch sw;
	sw.start();

	foreach(i, ref row; entities)
	{
		row.transform.x += row.velocity1.x * 2 + row.velocity2.x * 3 + row.velocity3.x * 4;
		row.transform.y += row.velocity1.y * 2 + row.velocity2.y * 3 + row.velocity3.y * 4;
		row.transform.z += row.velocity1.z * 2 + row.velocity2.z * 3 + row.velocity3.z * 4;
	}

	printBenchResult("%s : AOS iteration, 4 components", sw.peek);
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

void benchApiFullJoin2(alias StorageT)()
{
	StorageT!Transform transformStorage;
	StorageT!Velocity velocityStorage;

	foreach(index; 0..entityCount)
	{
		transformStorage.set(EntityId(index), Transform(0, 0, 0));
		velocityStorage.set(EntityId(index), Velocity(1, 1, 1));
	}

	auto query = componentQuery(transformStorage, velocityStorage);

	StopWatch sw;
	sw.start();

	foreach(row; query)
	{
		row.transform_0.x += row.velocity_1.x;
		row.transform_0.y += row.velocity_1.y;
		row.transform_0.z += row.velocity_1.z;
	}

	printBenchResult("%s : Full hash join, 2 components, "~__traits(identifier, StorageT), sw.peek);
}

void benchApiFullJoin4(alias StorageT)()
{
	StorageT!Transform transformStorage;
	StorageT!Velocity velocityStorage1;
	StorageT!Velocity velocityStorage2;
	StorageT!Velocity velocityStorage3;

	foreach(index; 0..entityCount) {
		transformStorage.set(EntityId(index), Transform(0, 0, 0));
		velocityStorage1.set(EntityId(index), Velocity(1, 1, 1));
		velocityStorage2.set(EntityId(index), Velocity(1, 1, 1));
		velocityStorage3.set(EntityId(index), Velocity(1, 1, 1));
	}

	auto query = componentQuery(transformStorage, velocityStorage1, velocityStorage2, velocityStorage3);

	StopWatch sw;
	sw.start();

	foreach(row; query)
	{
		row.transform_0.x += row.velocity_1.x * 2 + row.velocity_2.x * 3 + row.velocity_3.x * 4;
		row.transform_0.y += row.velocity_1.y * 2 + row.velocity_2.y * 3 + row.velocity_3.y * 4;
		row.transform_0.z += row.velocity_1.z * 2 + row.velocity_2.z * 3 + row.velocity_3.z * 4;
	}

	printBenchResult("%s : Full hash join, 4 components, "~__traits(identifier, StorageT), sw.peek);
}

void benchApiPartialJoin(alias StorageT)()
{
	StorageT!Transform transformStorage;
	StorageT!Velocity velocityStorage1;
	StorageT!Velocity velocityStorage2;
	StorageT!Velocity velocityStorage3;

	foreach(index; 0..entityCountMin) {
		velocityStorage1.set(EntityId(index), Velocity(1, 1, 1));
		velocityStorage2.set(EntityId(index), Velocity(1, 1, 1));
	}
	foreach(index; 0..entityCountMed) {
		velocityStorage3.set(EntityId(index), Velocity(1, 1, 1));
	}
	foreach(index; 0..entityCountMax) {
		transformStorage.set(EntityId(index), Transform(0, 0, 0));
	}

	auto query = componentQuery(transformStorage, velocityStorage1, velocityStorage2, velocityStorage3);

	StopWatch sw;
	sw.start();

	foreach(row; query)
	{
		row.transform_0.x += row.velocity_1.x * 2 + row.velocity_2.x * 3 + row.velocity_3.x * 4;
		row.transform_0.y += row.velocity_1.y * 2 + row.velocity_2.y * 3 + row.velocity_3.y * 4;
		row.transform_0.z += row.velocity_1.z * 2 + row.velocity_2.z * 3 + row.velocity_3.z * 4;
	}

	printBenchResult("%s : Partial hash join, 4 components, "~__traits(identifier, StorageT), sw.peek);
}

void benchApiPartialJoinEman(alias StorageT)()
{
	EntityManager eman;

	eman.registerComponent!Transform();
	eman.registerComponent!Velocity1();
	eman.registerComponent!Velocity2();
	eman.registerComponent!Velocity3();

	foreach(index; 0..entityCountMin) {
		eman.set(EntityId(index), Velocity1(1, 1, 1), Velocity2(1, 1, 1));
	}
	foreach(index; 0..entityCountMed) {
		eman.set(EntityId(index), Velocity3(1, 1, 1));
	}
	foreach(index; 0..entityCountMax) {
		eman.set(EntityId(index), Transform(0, 0, 0));
	}

	auto query = eman.query!(Transform, Velocity1, Velocity2, Velocity3);

	StopWatch sw;
	sw.start();

	foreach(row; query)
	{
		row.transform_0.x += row.velocity1_1.x * 2 + row.velocity2_2.x * 3 + row.velocity3_3.x * 4;
		row.transform_0.y += row.velocity1_1.y * 2 + row.velocity2_2.y * 3 + row.velocity3_3.y * 4;
		row.transform_0.z += row.velocity1_1.z * 2 + row.velocity2_2.z * 3 + row.velocity3_3.z * 4;
	}

	printBenchResult("%s : Partial hash join, 4 components, eman, "~__traits(identifier, StorageT), sw.peek);
}

void test()
{
	EntitySet entities1;
	EntitySet entities2;
	CustomHashmapComponentStorage!Velocity velocityStorage;
	auto query = componentQuery(entities1, entities2, velocityStorage);
}

void benchApiPartialJoinSet()
{
	EntitySet entities;
	CustomHashmapComponentStorage!Transform transformStorage;
	CustomHashmapComponentStorage!Velocity velocityStorage1;
	CustomHashmapComponentStorage!Velocity velocityStorage2;
	CustomHashmapComponentStorage!Velocity velocityStorage3;

	foreach(index; 0..entityCountMin) {
		entities.set(index);
		velocityStorage1.set(EntityId(index), Velocity(1, 1, 1));
		velocityStorage2.set(EntityId(index), Velocity(1, 1, 1));
	}
	foreach(index; 0..entityCountMed) {
		velocityStorage3.set(EntityId(index), Velocity(1, 1, 1));
	}
	foreach(index; 0..entityCountMax) {
		transformStorage.set(EntityId(index), Transform(0, 0, 0));
	}

	auto query = componentQuery(entities, transformStorage, velocityStorage1, velocityStorage2, velocityStorage3);

	StopWatch sw;
	sw.start();

	foreach(row; query)
	{
		row.transform_1.x += row.velocity_2.x * 2 + row.velocity_3.x * 3 + row.velocity_4.x * 4;
		row.transform_1.y += row.velocity_2.y * 2 + row.velocity_3.y * 3 + row.velocity_4.y * 4;
		row.transform_1.z += row.velocity_2.z * 2 + row.velocity_3.z * 3 + row.velocity_4.z * 4;
	}

	printBenchResult("%s : Partial hash join, 4 components + EntitySet", sw.peek);
}

void benchApiPartialJoinOnlySet()
{
	EntitySet entities1;
	EntitySet entities2;
	EntitySet entities3;
	EntitySet entities4;

	foreach(index; 0..entityCountMin) {
		entities1.set(index);
		entities2.set(index);
	}
	foreach(index; 0..entityCountMed) {
		entities3.set(index);
	}
	foreach(index; 0..entityCountMax) {
		entities4.set(index);
	}

	auto query = componentQuery(entities1, entities2, entities3, entities4);

	StopWatch sw;
	sw.start();

	size_t counter;
	foreach(row; query)
	{
		++counter;
	}

	printBenchResult("%s : Partial hash join, 4 EntitySets", sw.peek);
	writefln("counter %s", counter);
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
