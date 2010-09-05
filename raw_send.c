/*
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <netdb.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/param.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <net/if_arp.h>
#include <netinet/in.h>
#include <netinet/if_ether.h>
#include <netinet/ip.h>
#include <netinet/udp.h>

//#include <linux/if_packet.h>
//#include <linux/if_ether.h>

#define ETH_DATA_LEN	1500

#include "raw_send.h"

int
main(int argc, char **argv)
{
    int rawfd;
    ssize_t size;
    unsigned int argsfound = 0;
    char src_host[MAXHOSTNAMELEN];
    char dst_host[MAXHOSTNAMELEN];
    int dport = 0, len, totlen;
    char packet[ETH_DATA_LEN];
    struct ip *iph = (struct ip *)packet;
    char *body = (packet + sizeof(struct ip) + sizeof(struct udphdr));
    struct sockaddr_in dst_sin;
    char *msg = SAMPLE_MESSAGE;

    bzero(src_host, sizeof(src_host));
    bzero(dst_host, sizeof(dst_host));
    bzero(packet, sizeof(packet));
    bzero(&dst_sin, sizeof(dst_sin));

    if ((argsfound = parse_cmdline(argc, argv, 
				   src_host, 
				   dst_host, 
				   &dport)) < ARGSMIN) {
		usage(argv[0]);
		exit(0);
    }

    rawfd = raw_udpip_init();

    fill_udpip_hdr(packet, src_host, dst_host, dport, msg);

    dst_sin.sin_addr.s_addr = iph->ip_src.s_addr;
    dst_sin.sin_family = AF_INET;

    len = strlen(msg);
    strncpy(body, msg, len);
    totlen = len + sizeof(struct udphdr) + sizeof(struct ip);

    if ((size = sendto(rawfd, (void *)packet, totlen, 0, (struct sockaddr *)&dst_sin, sizeof(dst_sin))) == -1) {
		perror("sendto");
		exit(1);
    }

    return 0;
}

int
raw_udpip_init()
{
    int sockfd;
    int on = 1;

    if ((sockfd = socket(PF_INET, SOCK_RAW, IPPROTO_RAW)) == -1) {
		perror("socket");
		exit(1);
    }
	
    if (setsockopt(sockfd, SOL_SOCKET, SO_BROADCAST, &on, sizeof(on)) < 0) {
		perror("setsockopt SO_BROADCAST");
		exit(1);
    }
	
    if (setsockopt(sockfd, IPPROTO_IP, IP_HDRINCL, &on, sizeof(on)) < 0) {
		perror("setsockopt IP_HDRINCL");
		exit(1);
    }

    return sockfd;
}


/*
+------------------------------------------------------------------+
|IP Header fields modified on sending when IP_HDRINCL is specified |
+------------------------------------------------------------------+
|  Sending fragments with IP_HDRINCL is not supported currently.   |
+--------------------------+---------------------------------------+
|IP Checksum               |Always filled in.                      |
+--------------------------+---------------------------------------+
|Source Address            |Filled in when zero.                   |
+--------------------------+---------------------------------------+
|Packet Id                 |Filled in when passed as 0.            |
+--------------------------+---------------------------------------+
|Total Length              |Always filled in.                      |
+--------------------------+---------------------------------------+
 */

void
fill_udpip_hdr(char *packet,
	       char *src_host,
	       char *dst_host,
	       int dport,
	       char *msg)
{
    struct ip *iph;
    struct udphdr *udph;
    unsigned long saddr, daddr;
    int len;

    len = strlen(msg);

    saddr = translate_hostname(src_host);
    daddr = translate_hostname(dst_host);

    iph = (struct ip *)packet;
    udph = (struct udphdr *)(packet + sizeof(struct ip));

    iph->ip_v = 4;
    iph->ip_hl = 5;
    iph->ip_tos = 0;
    iph->ip_len = sizeof(struct ip) + sizeof(struct udphdr) + len;
    iph->ip_id = 0;
    iph->ip_off = 0;
    iph->ip_ttl = 16;
    iph->ip_p = IPPROTO_UDP;
    iph->ip_sum = 0;
    iph->ip_src.s_addr = saddr;
    iph->ip_dst.s_addr = daddr;

    udph->uh_sport = htons(dport);  /* dummy */
    udph->uh_dport = htons(dport);
    udph->uh_ulen = htons(len + sizeof(struct udphdr));
    udph->uh_sum = 0;

    return;
}

unsigned int
parse_cmdline(int argc,
	      char *argv[],
	      char *src_host,
	      char *dst_host,
	      int *dport)
{
    int c;
    unsigned int argsfound = 0;
    extern char *optarg;
    extern int optind;
    
    while ((c = getopt(argc, argv, "s:d:p:")) != -1) {
	switch ((char)c) {
	case 's':
	    argsfound |= SHOSTFOUND;
	    strncpy(src_host, optarg, MAXHOSTNAMELEN);
	    fprintf(stderr, "src host %s\n", src_host);
	    break;
	case 'd':
	    argsfound |= DHOSTFOUND;
	    strncpy(dst_host, optarg, MAXHOSTNAMELEN);
	    fprintf(stderr, "dst host %s\n", dst_host);
	    break;
	case 'p':
	    argsfound |= PORTFOUND;
	    *dport = (int)strtol(optarg, NULL, 10);
	    fprintf(stderr, "dst port = %d\n", *dport);
	    break;
	default:
	    fprintf(stderr, "Unknown option %c\n", c);
	    usage(argv[0]);
	    exit(0);
	    break;
	}
    }
    
    return argsfound;
}

unsigned long
translate_hostname(char *hostname)
{
    unsigned long addr;
    struct hostent *serv_host;
    
    if (isdigit(hostname[0])) {
	addr = inet_addr(hostname);
    } else {
	serv_host = gethostbyname(hostname);
	bcopy(serv_host->h_addr, (char *)&addr, sizeof(addr));
    }
    
    return addr;
}

void
usage(char *progname)
{
    fprintf(stderr, 
	    "Usage: %s -s <src host> -d <dst host> -p <dst port>\n", 
	    progname);
}
