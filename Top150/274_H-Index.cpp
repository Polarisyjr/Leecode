class Solution {
public:
    int hIndex(vector<int>& citations) {
        std::sort(citations.begin(), citations.end());
        int cnt=0;
        for(int i=citations.size()-1; i>=0; i--){
            //std::cout<<citations[i]<<std::endl;
            if(citations[i]>cnt){
                cnt++;
            }
            else{
                break;
            }
        }
        return cnt;
    }
};