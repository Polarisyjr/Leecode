/**
 * Definition for a binary tree node.
 * struct TreeNode {
 *     int val;
 *     TreeNode *left;
 *     TreeNode *right;
 *     TreeNode() : val(0), left(nullptr), right(nullptr) {}
 *     TreeNode(int x) : val(x), left(nullptr), right(nullptr) {}
 *     TreeNode(int x, TreeNode *left, TreeNode *right) : val(x), left(left), right(right) {}
 * };
 */
class Solution {
public:
    int maxDepth(TreeNode* root) {
        if (!root) return 0;
        int leftDepth = maxDepth(root->left);
        int rightDepth = maxDepth(root->right);
        return 1 + max(leftDepth, rightDepth);
    }
};

// 遍历的思路
class Solution {

    // 记录最大深度
    int res = 0;

    // 记录遍历到的节点的深度
    int depth = 0;

public:
    int maxDepth(TreeNode* root) {
        traverse(root);
        return res;
    }

    // 遍历二叉树
    void traverse(TreeNode* root) {
        if (root == nullptr) {
            return;
        }

        // 前序遍历位置（进入节点）增加深度
        depth++;
        // 遍历到叶子节点时记录最大深度
        if (root->left == nullptr && root->right == nullptr) {
            res = std::max(res, depth);
        }
        traverse(root->left);
        traverse(root->right);

        // 后序遍历位置（离开节点）减少深度
        depth--;
    }
};