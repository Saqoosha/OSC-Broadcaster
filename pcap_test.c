#include <stdio.h>
#include <stdlib.h>
#include <pcap.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>


char errbuf[PCAP_ERRBUF_SIZE];

void list_all_devices() {
	pcap_if_t *alldevsp;
	// Retrieve the device list from the local machine
	if (pcap_findalldevs(&alldevsp, errbuf) == -1) { 
		printf("%s\n", errbuf);
		
	} else {
		pcap_if_t *d = alldevsp;
		while (d){
			if (d->addresses != NULL) {
				//				NIPCDevice device;
				//				struct sockaddr_in *sa = (sockaddr_in *)d->addresses->addr;
				printf("%s\n", d->name);
				//				// IP address (unsigned long)
				//				device.address = sa->sin_addr.s_addr;
				//				if(device.address != 0){ // (0,0,0,0) is bad
				//					// a name for pcap_open_live()
				//					device.name = d->name;
				//					// a human-readable description
				//					device.description = d->description;
				//					list->push_back(device);
				//				}
			}
			d = d->next;
		}
		// free an interface list returned by pcap_findalldevs().
		pcap_freealldevs(alldevsp);
	}
}


int main(int argc, char *argv[])
{
	printf("args: %d\n", argc);
	for (int i = 0; i < argc; i++) {
		printf("\t%d: %s\n", i, argv[i]);
	}
	
	char *dev;
	
//	dev = pcap_lookupdev(errbuf);
//	if (dev == NULL) {
//		fprintf(stderr, "ディバイスが見つかりませんでした: %s\n", errbuf);
//		exit(1);
//	}
//	printf("ディバイス: %s\n", dev);
	
//	pcap_t *handle;
//	
//	handle = pcap_open_live("en1", BUFSIZ, 1, 1000, errbuf);
//	if (handle == NULL) {
//		fprintf(stderr, "ディバイス「%s」を開けませんでした: %s\n", dev, errbuf);
//		exit(1);
//	}
//
//	struct pcap_pkthdr header;
//	const u_char *packet;
//	while (1) {
//		packet = pcap_next(handle, &header);
//		printf("取得したパケット長 [%d]\n", header.len);
//	}
//	pcap_close(handle);
	
	list_all_devices();
	
	return 0;
}


