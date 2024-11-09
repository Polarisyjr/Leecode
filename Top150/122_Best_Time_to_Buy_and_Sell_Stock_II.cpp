class Solution {
public:
    int maxProfit(vector<int>& prices) {
        if(prices.size()==1) return 0;
        int ret=0, i=0;
        bool hold=0;
        while(i<prices.size()-1){
            if(!hold && prices[i]<prices[i+1]){
                ret-=prices[i]; // buy
                hold=1;
                //std::cout<<"buy "<<prices[i]<<std::endl;
            }
            else if((hold && prices[i]>prices[i+1])){
                ret+=prices[i]; // sell
                hold=0;
                //std::cout<<"sell "<<prices[i]<<std::endl;
            }
            i++;
        }
        if(hold) ret+=prices[i];
        return ret;
    }
};