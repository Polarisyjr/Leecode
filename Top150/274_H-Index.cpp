class Solution {
public:
    int hIndex(vector<int>& citations) {
        sort(citations);
        int i=citations.size()-1;
        int cnt=0;
        for(int i=citations.size()-1; i>=0; i--){
            if(citations[i]>cnt){
                cnt++;
            }
            else return i;
        }
    }
};