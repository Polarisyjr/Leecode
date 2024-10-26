#include <vector>

class Solution {
public:
    int removeElement(std::vector<int>& nums, int val) {
        int i = 0;
        for (int j = 0; j < nums.size(); j++) {
            if (nums[j] != val) {
                nums[i] = nums[j];
                i++;
            }
        }
        return i;
    }
};

class MySolution {
public:
    int removeElement(vector<int>& nums, int val) {
        int cnt=0;
        for(int i=0; i<nums.size(); i++){
            if(nums[i]==val){
                for(int j=i+1; j<nums.size(); j++){
                    if(nums[j]!=val){
                        std::swap(nums[i], nums[j]);
                        cnt--;
                        break;
                    }
                }
                cnt++;
            }
        }
        return nums.size()-cnt;
    }
};

