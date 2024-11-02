class Solution {
public:
    string convert(string s, int numRows) {
        std::string ret=s;
        if(s.size()==1) return ret;
        int ret_idx=0;
        int i=0, j=numRows-1;
        int cnt=0;
        while(i+2*cnt*(numRows-1-i)<s.size()){
            ret[ret_idx++]=s[i+2*cnt*(numRows-1)];
            cnt++;
        }
        
        for(int k=1; k<numRows-1; k++){
            cnt=0;
            int flag=0;
            while(1){
                int target_idx=0;
                if(!flag){
                    target_idx = k+2*cnt*(numRows-1-k);
                }else{
                    target_idx = k+2*cnt*k;
                }
                if(target_idx>=s.size()) break;
                ret[ret_idx++]=s[target_idx];
                cnt++; 
                flag=(flag==0);
            }
        }
        cnt=0;
        while(j+2*cnt*(numRows-1)<s.size()){
            ret[ret_idx++]=s[j+2*cnt*(numRows-1)];
            cnt++;
        }
        return ret;
    }
};