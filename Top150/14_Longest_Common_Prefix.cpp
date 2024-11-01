class Solution {
public:
    string longestCommonPrefix(vector<string>& v) {
        string ans="";
        sort(v.begin(),v.end());
        int n=v.size();
        string first=v[0],last=v[n-1];
        for(int i=0;i<min(first.size(),last.size());i++){
            if(first[i]!=last[i]){
                return ans;
            }
            ans+=first[i];
        }
        return ans;
    }
};



class MySolution {
public:
    string longestCommonPrefix(vector<string>& strs) {
        int cnt=0;
        for(int j=cnt; j<strs[0].length();j++){ 
            for(int i=1; i<strs.size(); i++){
                if(strs[i][j]!=strs[0][j]){
                    return std::string(strs[0], 0, cnt);
                }
            }  
            cnt++;
        }
        return std::string(strs[0], 0, cnt);
    }
};