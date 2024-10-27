class Solution {
public:
    int majorityElement(vector<int>& nums) {
        sort(nums.begin(), nums.end());
        int n = nums.size();
        return nums[n/2];
    }
};

class MySolution {
public:
    int majorityElement(vector<int>& nums) {
        std::unordered_map<int, int> hashmap;
        int max=0, num=0;
        for(int i=0; i<nums.size(); i++){
            if (hashmap.find(nums[i]) != hashmap.end()) {
                hashmap[nums[i]] = hashmap[nums[i]] + 1;
                
            }else{
                hashmap[nums[i]]=1;
            }
            if(max < hashmap[nums[i]]){
                max=hashmap[nums[i]];
                num=nums[i];
            }
        }
        return num;
    }
};
