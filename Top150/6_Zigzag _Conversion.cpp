class Solution {
public:
    string convert(string s, int numRows) {
        std::string ret=s;
        if(numRows==1) return ret;
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
            int target_idx=k;
            ret[ret_idx++]=s[target_idx];
            while(1){
                if(!flag){
                    target_idx = target_idx+2*(numRows-1-k);
                }else{
                    target_idx = target_idx+2*k;
                }
                if(target_idx>=s.size()) break;
                //std::cout<<target_idx<< " "<<s[target_idx]<<" "<<flag<<std::endl;
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