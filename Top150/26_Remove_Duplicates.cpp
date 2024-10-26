class Solution {
public:
    int removeDuplicates(vector<int>& nums) {
        int j = 1;
        for(int i = 1; i < nums.size(); i++){
            if(nums[i] != nums[i - 1]){
                nums[j] = nums[i];
                j++;
            }
        }
        return j;
    }
};

class MySolution {
public:
    int removeDuplicates(vector<int>& nums) {
        int i=1, j=0;
        while(i<nums.size() && j<nums.size()){
            if(nums[i-1]>=nums[i]){
                while(j<nums.size() && nums[i]>=nums[j]){
                    j++;
                    //std::cout<<i<<" "<< j<<std::endl;
                }
                if(j<nums.size()) std::swap(nums[i],nums[j]);
                //std::cout<<nums[i+1]<<" "<<nums[j]<<std::endl;  
            }else{
                i++;
            }
        }
        return i;
    }
};

