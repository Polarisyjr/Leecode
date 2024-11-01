class Solution {
public:
    int strStr(string haystack, string needle) {
        vector<int> next(needle.length(),-1);
        int i=-1,j=0;
        while(j<next.size()-1){
            if(i==-1||needle[i]==needle[j]){
                i++;j++;
                next[j]=i;
            }
            else i=next[i];
        }
        /*for(int k=0; k<next.size(); k++) {
            std::cout<< next[k]<< std::endl;
        }*/
        i=0;
        j=0;
        while (i < haystack.size() && j < (int)needle.size())
        {
            if (j == -1 || haystack[i] == needle[j])
            {
                ++i;
                ++j;
                //std::cout << haystack[i] <<" "<< needle[j]<< std::endl;
            }
            else{
                //std::cout << haystack[i] <<" "<< needle[j]<< std::endl;
                j = next[j];
            }
            if (j == needle.size())
            {
                return (i-j);
            }
        }
        return -1;
    }
};