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
        ListNode* trainingPlan(ListNode* head, int cnt) {
            ListNode* slow = head;
            ListNode* fast = head;
            for (int i = 0; i < cnt; i++) {
                fast = fast->next;
            }
           while (fast != nullptr) {
                slow = slow->next;
                fast = fast->next;
            }
            return slow;
        }
    };