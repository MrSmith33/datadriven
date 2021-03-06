module datadriven.api;

alias EntityId = ulong;

struct Component {
	string key;
}

template componentKey(C)
{
	import std.traits : hasUDA, getUDAs;
	static if (hasUDA!(C, Component))
		enum string componentKey = getUDAs!(C, Component)[0].key;
	else
		static assert(false, "Component " ~ C.stringof ~ " has no Component UDA");
}

// tests if CS is a Component storage of components C
template isComponentStorage(CS, C)
{
	enum bool isComponentStorage = is(typeof(
	(inout int = 0)
	{
		CS cs = CS.init;
		C c = C.init;
		EntityId id = EntityId.init;

		cs.set(id, c); // Can add component
		cs.remove(id); // Can remove component
		C* cptr = cs.get(id); // Can get component pointer

		foreach(key, value; cs)
		{
			id = key;
			c = value = c;
		}
	}));
}

// tests if CS is a Component storage of any component type
template isAnyComponentStorage(CS)
{
	static if (is(CS.ComponentType C))
		enum bool isAnyComponentStorage = isComponentStorage!(CS, C);
	else
		enum bool isAnyComponentStorage = false;
}

template isEntitySet(S)
{
	enum bool isEntitySet = is(typeof(
	(inout int = 0)
	{
		S s = S.init;
		EntityId id = EntityId.init;

		s.set(id); // Can add component
		s.remove(id); // Can remove component
		bool contains = s.get(id); // Can check presence

		foreach(key; s)
		{
			id = key;
		}
	}));
}

unittest
{
	struct A {}
	struct B
	{
		void set(EntityId);
		void remove(EntityId);
		bool get(EntityId);
		int opApply(int delegate(in EntityId) del) {
			return 0;
		}
	}
	struct C
	{
		void set(EntityId, int);
		void remove(EntityId);
		int* get(EntityId);
		int opApply(int delegate(in EntityId, ref int) del) {
			return 0;
		}
		alias ComponentType = int;
	}
	static assert(!isComponentStorage!(A, int));
	static assert(!isAnyComponentStorage!A);
	static assert(!isEntitySet!(A));

	static assert(!isComponentStorage!(B, int));
	static assert(!isAnyComponentStorage!B);
	static assert( isEntitySet!(B));

	static assert( isComponentStorage!(C, int));
	static assert( isAnyComponentStorage!C);
	static assert(!isEntitySet!(C));
}
