class Solution {
public:
    int jump(vector<int>& nums) {
        int n = nums.size();
	    vector<int> dp(n, 10001);
        dp[n - 1] = 0;
        for(int i = n - 2; i >= 0; i--) 
		    for(int jumpLen = 1; jumpLen <= nums[i]; jumpLen++) 
			    dp[i] = min(dp[i], 1 + dp[min(n - 1, i + jumpLen)]);  
	
        return dp[0];
    }
};

int jump(vector<int>& nums) {
	int n = size(nums), i = 0, maxReachable = 0, lastJumpedPos = 0, jumps = 0;
	while(lastJumpedPos < n - 1) {  // loop till last jump hasn't taken us till the end
		maxReachable = max(maxReachable, i + nums[i]);  // furthest index reachable on the next level from current level
		if(i == lastJumpedPos) {			  // current level has been iterated & maxReachable position on next level has been finalised
			lastJumpedPos = maxReachable;     // so just move to that maxReachable position
			jumps++;                          // and increment the level
	// NOTE: jump^ only gets updated after we iterate all possible jumps from previous level
	//       This ensures jumps will only store minimum jump required to reach lastJumpedPos
		}            
		i++;
	}
	return jumps;
}