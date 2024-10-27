class Solution {
public:
    int maxProfit(vector<int>& prices) {
        int min_price = INT_MAX;
        int max_profit = 0;
        for (int price : prices) {
            min_price = min(min_price, price);
            max_profit = max(max_profit, price - min_price);
        }
        return max_profit;
    }
};

class MySolution2 {
public:
    int maxProfit(vector<int>& prices) {
        int ret=0, max=0;
        for(int i=prices.size()-1; i>=0; i--){
            if(max<prices[i]) max=prices[i];
            if(max-prices[i]>ret) ret=max-prices[i];
        }
        return ret;
    }
};

class MySolution1 { //TLE
public:
    int maxProfit(vector<int>& prices) {
        int ret=0;
        for(int i=prices.size()-2; i>=0; i--){
            int max=0;
            //std::cout<<i<<" "<<prices[i]<<std::endl;
            for(int j=i+1; j<prices.size(); j++){
                if(prices[j]>max){
                    max=prices[j];
                }
            }
            //std::cout<<max<<std::endl;
            if(max-prices[i]>ret) ret=max-prices[i];
            //std::cout<<ret<<std::endl;
        }
        return ret;
    }
};