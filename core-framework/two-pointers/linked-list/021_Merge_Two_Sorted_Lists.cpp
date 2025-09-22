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
        ListNode* mergeTwoLists(ListNode* l1, ListNode* l2) {
            // virtual head node
            ListNode dummy(-1), *p = &dummy;
            ListNode *p1 = l1, *p2 = l2;
            
            while (p1 != nullptr && p2 != nullptr) {
                if (p1->val > p2->val) {
                    p->next = p2;
                    p2 = p2->next;
                } else {
                    p->next = p1;
                    p1 = p1->next;
                }
                // p pointer moves forward
                p = p->next;
            }
            
            if (p1 != nullptr) {
                p->next = p1;
            }
            
            if (p2 != nullptr) {
                p->next = p2;
            }
            
            return dummy.next;
        }
    };