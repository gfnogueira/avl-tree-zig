# avl-tree-zig

Self-balancing BST in Zig. Kata.

## Use case

Ordered set with `O(log n)` insert / remove / lookup and sorted iteration.

## Pros

- Strict balance (`|bf| <= 1`) → height stays near `log2(n)`.
- Faster lookups than red-black under read-heavy load.
- In-order traversal is sorted.

## Cons

- More rotations on write than red-black.
- Extra metadata per node (height).
- Hash map wins on point lookups when order doesn't matter.

## Build / test

```
zig build test --summary all
```

Zig 0.16.0.

## API

```zig
const avl = @import("avl");

var t = avl.Tree.init(allocator);
defer t.deinit();

try t.insert(42);
_ = t.contains(42);
_ = t.remove(42);

const sorted = try t.inOrder(allocator);
defer allocator.free(sorted);
```
