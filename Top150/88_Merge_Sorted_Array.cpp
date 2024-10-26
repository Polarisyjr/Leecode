#include <vector>

class Solution {
public:
    void merge(std::vector<int>& nums1, int m, std::vector<int>& nums2, int n) {
        int i = m - 1, j = n - 1, k = m + n - 1;
        while (i >= 0 && j >= 0) {
            if (nums1[i] > nums2[j]) {
                nums1[k--] = nums1[i--];
            } else {
                nums1[k--] = nums2[j--];
            }
        }
        while (j >= 0) {
            nums1[k--] = nums2[j--];
        }
    }
};


class MySolution {
public:
    void merge(vector<int>& nums1, int m, vector<int>& nums2, int n) {
        vector<int> nums3(m+n);
        if(m==0) nums1=nums2;
        if(n==0) return;
        int i=0, j=0;
        for(int k=0; k<m+n; k++){ 
            if(j>=n || (nums1[i]<=nums2[j] && i<m)){ 
                nums3[k]=nums1[i++];
            }else{
                nums3[k]=nums2[j++];
            }
        }
        nums1=nums3;
    }
};