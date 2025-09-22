/**
 * Definition for singly-linked list.
 * struct ListNode {
 *     int val;
 *     ListNode *next;
 *     ListNode() : val(0), next(nullptr) {}
 *     ListNode(int x) : val(x), next(nullptr) {}
 *     ListNode(int x, ListNode *next) : val(x), next(next) {}
 * };
 */
 class Solution {
    public:
        ListNode* mergeKLists(vector<ListNode*>& lists) {
            if (lists.empty()) return nullptr;
            ListNode dummy(-1), *p = &dummy;
            // *** use priority queue to maintain the smallest element ***
            auto cmp = [](ListNode* a, ListNode* b) { return a->val > b->val; };
            priority_queue<ListNode*, vector<ListNode*>, decltype(cmp)> pq(cmp);
            for (ListNode* head : lists) {
                if (head != nullptr) {
                    pq.push(head);
                }
            }
            while (!pq.empty()) {
                // get the smallest node, and add it to the result list
                ListNode* node = pq.top();
                pq.pop();
                p->next = node;
                if (node->next != nullptr) {
                    pq.push(node->next);
                }
                // p pointer moves forward
                p = p->next;
            }
            return dummy.next;
        }
    };