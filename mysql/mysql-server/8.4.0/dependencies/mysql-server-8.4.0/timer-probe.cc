#define _GNU_SOURCE
#include "my_rdtsc.h"
#include <sched.h>
#include <time.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <initializer_list>
static double now() { timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec+t.tv_nsec/1e9; }
static void require(bool yes,const char* s) { if(!yes) { std::fprintf(stderr,"FAIL: %s\n",s);std::exit(1); } }
int main() {
 MY_TIMER_INFO info{}; my_timer_init(&info);
 require(info.cycles.routine==MY_TIMER_ROUTINE_ASM_LOONGARCH64,"LoongArch routine selected");
 require(info.cycles.frequency>0,"nonzero calibrated frequency");
 unsigned long long previous=my_timer_cycles(),first=previous,duplicates=0;
 for(int i=0;i<1000000;i++) { auto current=my_timer_cycles();require(current>=previous,"counter regression");duplicates+=(current==previous);previous=current; }
 require(previous>first,"counter progresses");
 std::printf("samples=1000000 duplicates=%llu frequency=%llu\n",duplicates,info.cycles.frequency);
 for(long delay: {10000000L,100000000L,250000000L}) {
  double start=now();auto a=my_timer_cycles();timespec requested{0,delay};nanosleep(&requested,nullptr);auto b=my_timer_cycles();double elapsed=now()-start;
  double estimate=double(b-a)/info.cycles.frequency,error=std::abs(estimate-elapsed)/elapsed;
  std::printf("wall_seconds=%.9f counter_seconds=%.9f relative_error=%.6f\n",elapsed,estimate,error);
  require(error<0.02,"counter frequency differs from CLOCK_MONOTONIC by >=2%");
 }
 cpu_set_t original;require(sched_getaffinity(0,sizeof(original),&original)==0,"read affinity");
 previous=my_timer_cycles();int count=0;
 for(int cpu=0;cpu<CPU_SETSIZE;cpu++) if(CPU_ISSET(cpu,&original)) {
  cpu_set_t one;CPU_ZERO(&one);CPU_SET(cpu,&one);require(sched_setaffinity(0,sizeof(one),&one)==0,"set affinity");
  auto current=my_timer_cycles();require(current>=previous,"counter regression across CPUs");previous=current;count++;
 }
 require(sched_setaffinity(0,sizeof(original),&original)==0,"restore affinity");
 std::printf("cross_cpu_migration_checked=%d\nPASS\n",count);
}
