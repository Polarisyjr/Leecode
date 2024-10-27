class Solution {
public:
    int removeDuplicates(std::vector<int>& nums) {
        int j = 1;
        for (int i = 1; i < nums.size(); i++) {
            if (j == 1 || nums[i] != nums[j - 2]) {
                nums[j++] = nums[i];
            }
        }
        return j;
    }
};


class MySolution {
public:// each unique element appears at most twice
    int removeDuplicates(vector<int>& nums) {
        int i=0, j=0, cnt=1;
        while(j<nums.size()){
            while(j+cnt<nums.size() && nums[j]==nums[j+cnt]){
                cnt++;
            }
            if(cnt>2){
                nums[i]=nums[j];
                nums[i+1]=nums[j+1];
                i+=2;
            }else{
                for(int k=0;k<cnt;k++){
                    nums[i+k]=nums[j+k];
                }
                i+=cnt;
            }
            j+=cnt;
            cnt=1;
        }
        return i;
    }
};