class Solution {
public:
    void rotate(vector<int>& nums, int k) {
        k=k%nums.size();
        vector<int> temp(k,0);
        for(int i=0; i<temp.size();i++){
            temp[i]=nums[nums.size()-k+i];
        }
        for(int j=0; j<nums.size()-k; j++){
            nums[nums.size()-1-j] = nums[nums.size()-1-k-j];
        }
        for(int j=0; j<k; j++){
            nums[j] = temp[j];
        }
    }
};

/*3. Reverse the first n - k elements, the last k elements, and then all the n elements.
Time complexity: O(n). Space complexity: O(1).*/

    class Solution 
    {
    public:
        void rotate(int nums[], int n, int k) 
        {
            k = k%n;
    
            // Reverse the first n - k numbers.
            // Index i (0 <= i < n - k) becomes n - k - i.
            reverse(nums, nums + n - k);
            
            // Reverse tha last k numbers.
            // Index n - k + i (0 <= i < k) becomes n - i.
            reverse(nums + n - k, nums + n);
            
            // Reverse all the numbers.
            // Index i (0 <= i < n - k) becomes n - (n - k - i) = i + k.
            // Index n - k + i (0 <= i < k) becomes n - (n - i) = i.
            reverse(nums, nums + n);
        }
    };

/*4. Swap the last k elements with the first k elements.
Time complexity: O(n). Space complexity: O(1).*/

class Solution 
{
public:
    void rotate(int nums[], int n, int k) 
    {
        for (; k = k%n; n -= k, nums += k)
        {
            // Swap the last k elements with the first k elements. 
            // The last k elements will be in the correct positions
            // but we need to rotate the remaining (n - k) elements 
            // to the right by k steps.
            for (int i = 0; i < k; i++)
            {
                swap(nums[i], nums[n - k + i]);
            }
        }
    }
};