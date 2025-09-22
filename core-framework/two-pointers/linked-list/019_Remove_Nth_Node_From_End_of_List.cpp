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
        ListNode* removeNthFromEnd(ListNode* head, int n) {
            ListNode dummy(-1);
            dummy.next = head;
            ListNode* x = findFromEnd(dummy, n + 1);
            x->next = x->next->next;
            return dummy.next;
        }
    private:
        ListNode* findFromEnd(ListNode* head, int k) {
            ListNode* slow = head;
            ListNode* fast = head;
            for (int i = 0; i < k & fast != nullptr; i++) {
                fast = fast->next;
            }
            while (fast != nullptr) {
                slow = slow->next;
                fast = fast->next;
            }
            return slow;
        }
};
        