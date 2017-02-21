module datadriven.bench_eplus;

import std.datetime;
import std.stdio;

import datadriven.api;
import datadriven.storage;
import datadriven.components;
import datadriven.query;
import datadriven.entityman;

void bench_EntityPlus()
{
	runTest(1_000, 1_000_000, 3);
	runTest(10_000, 1_000_000, 3);
	runTest(30_000, 100_000, 3);
	runTest(100_000, 100_000, 5);
	runTest(10_000, 1_000_000, 1_000);
	runTest(100_000, 1_000_000, 1_000);
}

void runTest(int entityCount, int iterationCount, int tagProb)
{
	writefln("Count: %s ItrCount: %s TagProb: %s",
		entityCount, iterationCount, tagProb);
	datadrivenTest(entityCount, iterationCount, tagProb);
}

void datadrivenTest(int entityCount, int iterationCount, int tagProb)
{
	@Component("component.Int") static struct Int { int data; }
	@Component("component.Tag") static struct Tag {}
	EntityManager eman;
	eman.registerComponent!Int;
	eman.registerComponent!Tag;

	startIteration;
	foreach (index; 0..entityCount)
	{
		EntityId eid = index;
		eman.set(eid, Int(index));
		if (index % tagProb == 0)
			eman.set(eid, Tag.init);
	}
	endIteration;
	writefln("Add entities: %s", lastIterationTime.fmtDur);

	ulong sum = 0;
	startIteration;
	foreach (i; 0..iterationCount)
	{
		foreach (row; eman.query!(Int, Tag))
		{
			sum += row.int_0.data;
		}
	}
	endIteration;
	writefln("For_each entities: %s", lastIterationTime.fmtDur);
	writeln(sum);
}

MonoTime iterationStartTime;
Duration iterationsSumTime;
Duration lastIterationTime;

void startIteration() {
	iterationStartTime = MonoTime.currTime;
}

void endIteration() {
	lastIterationTime = MonoTime.currTime - iterationStartTime;
	iterationsSumTime += lastIterationTime;
}

string fmtDur(Duration dur)
{
	import std.string : format;
	int seconds, msecs, usecs;
	dur.split!("seconds", "msecs", "usecs")(seconds, msecs, usecs);
	return format("%s.%03s,%03ss", seconds, msecs, usecs);
}
