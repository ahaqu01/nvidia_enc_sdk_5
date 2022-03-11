#include <iostream>

using namespace std;

int getFileName(char *&fileName)
{
	fileName = "zhou";

	return 0;
}

int main()
{
	char *fileName = "yu00";

	getFileName(fileName);
	cout<<"fileName = "<<fileName<<endl;

	return 0;
}
