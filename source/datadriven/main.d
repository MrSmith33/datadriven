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

void main()
{
	writeln("BENCH ITERATION");
	//benchIteration();
	benchIteration2();
	writeln("BENCH JOIN");
	//benchBinarySearchJoin();
	//benchBinarySearchJoinFull();
	benchApiJoinBalanced();
	benchApiJoinBalanced2();
}
