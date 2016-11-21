This is entity component system (ECS) type library.

## Features

- Automatic code gen for queries (basically inner join)
- Dynamic registration of component types
- Convenient entity manager

## Example

```
EntityManager eman;

eman.registerComponent!Transform(); // stored in HashMap
eman.registerComponent!Velocity(); // stored in HashMap
eman.registerComponent!FlagComponent(); // stored in HashSet

eman.set(0, Transform(0, 0, 0), Velocity(10, 10, 10), FlagComponent());
eman.set(1, Transform(1, 1, 1), Velocity(10, 10, 10), FlagComponent());
eman.set(2, Transform(2, 2, 2), Velocity(10, 10, 10), FlagComponent());
eman.set(3, Transform(3, 3, 3), Velocity(10, 10, 10));

// will get all entities with given component types
auto query = eman.query!(Transform, Velocity, FlagComponent);

foreach(row; query) {
	writefln("%s %s %s", row.id, *row.transform_0, *row.velocity_1);
}

eman.remove(0); // Remove all components of entity

assert(!eman.has!Transform(0)); // Can check if has component
assert(!eman.has!Velocity(0));
assert(!eman.has!FlagComponent(0));
```

Look at `main.d`, `benchmark.d` for more examples.