# Binary Tree — Problem-Solving Patterns

Binary tree problems generally fall into two common thinking patterns:

1. Traversal-based pattern

   Ask: Can you obtain the answer by traversing the tree once?

   If yes, implement a `traverse` function and use external (or captured) variables to collect results while visiting nodes. This is the "traversal" pattern.

2. Divide-and-conquer (recursive-return) pattern

   Ask: Can you define a recursive function whose return value for a node can be computed from the return values of its child subtrees?

   If yes, clearly define the recursive function's contract (what it returns for a given node) and use its return values to compose the solution for the parent node. This is the "divide-and-conquer" pattern.

From a single-node perspective, think about what each node should do and when it should do it (preorder / inorder / postorder). You don't need to manually handle every node — the recursion will apply the same logic to all nodes.

---

Tips:

- When using the traversal pattern, choose the traversal order that best fits the problem and update external state accordingly.
- When using the recursive-return pattern, write down the return type and meaning first (for example: "the function returns the height of the subtree", or "returns whether the subtree is balanced"). That makes composing parent results straightforward.

Keep these two patterns in mind when approaching binary tree problems — most solutions can be expressed as one of them or a combination of both.