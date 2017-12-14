# PMP profiler for Windows

The credits for inventing PMP (Poor Man's Profiler) go to [Domas](https://dom.as/) . Back in the olden days, he wrote a [20-line bash script](https://poormansprofiler.org/) , mixed some gdb and awk into it, et voila, which helped generation of programmers to analyze waits and stalls inside Linux programs.

This is the Windows port of it, no bash and awk involved, just a Powershell and Debugging tools for Windows.

# Preparations

PMP  uses cdb debugger, so it needs to be on the machine where profiling is running
* Download and install Debugging tools for Windows. The location changes  over time, but Google is your friend. Recently, it is part of Windows SDK. 
* Assuming you are going to profile 64bit programs, adjust your path PATH to include 64bit cdb.exe (on my system it means adding C:\Program Files (x86)\Windows Kits\10\Debuggers\x64 to PATH)
* Suggestion : set environment variable \_NT_SYMBOL_PATH=srv\*c:\symbols\*https://msdl.microsoft.com/download/symbols

# Using pmp, example

Here is an example of using the tool.
* Start program that you're going to profile (in the example above mysqld)
* Start the benchmark run (e.g sysbench)

Run command, similar to the below one.
( the example takes 100 probes, sleeps 2 seconds between  probes, excludes ntdll and kernel32, and shows the results in a compact form. If a callstack appears less than 3 times, it won't be includes into resulting output)

```
PS D:\win-pmp> .\pmp.ps1 -probes 100 -name mysqld  -sleep 2 -cleanstack 1 -only_my_code 1 -compact 1 -min_threshold 3
```

It will produce the output similar to this 

```
1000 GetQueuedCompletionStatus,os_aio_windows_handler,os_aio_handler,fil_aio_wait,io_handler_thread)
3G00 SleepConditionVariableCS,os_event::wait,os_event::wait_low,srv_resume_thread,srv_worker_thread
...
38 WriteFile,vio_write_pipe,net_real_write,net_flush,net_send_ok,net_send_eof,Protocol::end_statement,dispatch_command..
19 inline_mysql_mutex_lock,Table_cache_instance::lock_and_check_contention,tc_acquire_table,tdc_acquire_share,open_table.
19 rw_pr_wrlock,inline_mysql_prlock_wrlock,MDL_map::find_or_insert,MDL_context::try_acquire_lock_impl,MDL_context::acquire_lock,open_table_get_mdl_lock,open_table,open_and_proc
ess_table,open_tables,open_and_lock_tables

16 ReadFile,vio_read_pipe,my_real_read,my_net_read_packet_reallen,my_net_read_packet,do_comman..

6 ReadFile,TP_connection_win::start_io,tp_callback
```

Interpreting the results
1. Exclude threads that almost always sleep( e.g io_handler_thread here, or serv_worker_thread)
2. Look into mutex or rwlock contention (in this example, Table_cache and MDL locks are relatively hot ones). 


That's it. 