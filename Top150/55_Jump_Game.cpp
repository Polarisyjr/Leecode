class Solution {
public:
    bool canJump(vector<int>& nums) {
        int goal = nums.size() - 1;

        for (int i = nums.size() - 2; i >= 0; i--) {
            if (i + nums[i] >= goal) {
                goal = i;
            }
        }

        return goal == 0;        
    }
};

class Solution {
public:
    bool function(int index, int &n, vector<int>& nums, vector<int>& dp)
    {
        if (index >= n - 1) 
        {
            return true;
        }
        
        if (dp[index] != -1)
        {
            return dp[index];
        }

        int maxJump = nums[index];
        for (int i = 1; i <= maxJump; i++) 
        {
            if (function(index + i, n, nums, dp)) 
            {
                return dp[index] = true;
            }
        }
        return dp[index] = false;
    }

    bool canJump(vector<int>& nums) {
        int n = nums.size();
        vector<int>dp(n,-1);
        return function(0,n,nums,dp);
    }
};

class Solution {
public:
    bool canJump(vector<int>& nums) {
        int maxIdx = nums[0];

        for (int i = 0; i < nums.size(); ++i) {
            if (maxIdx >= nums.size() - 1) return true;

            if (nums[i] == 0 && maxIdx == i) return false;

            if (i + nums[i] > maxIdx) maxIdx = i + nums[i];
        }

        return true;
    }
};