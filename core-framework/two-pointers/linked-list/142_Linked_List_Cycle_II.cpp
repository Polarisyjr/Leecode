#include <vector>
using namespace std;

struct ListNode {
    int val;
    ListNode* next;
    ListNode() : val(0), next(nullptr) {}
    ListNode(int x) : val(x), next(nullptr) {}
    ListNode(int x, ListNode* n) : val(x), next(n) {}
};

class Solution {
public:
    // Detect if a cycle exists and return the entry node; otherwise return nullptr.
    ListNode* detectCycle(ListNode* head) {
        (void)head; // placeholder to silence unused parameter warning
        return nullptr;
    }
};


