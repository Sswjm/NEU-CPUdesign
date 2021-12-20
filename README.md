# NEU-CPUdesign
本实验为东北大学2021年秋季计算机系统课程的实验代码仓库，课程仓库位于https://github.com/fluctlight001/SampleCPU
实验实现了一个具有51条MIPS指令的cpu
# 工作进展
11.28 完成regfile数据相关接线

12.3 更新至lw指令，完成流水线暂停相关操作

12.5 更新至xori

12.8 更新至jalr

12.11更新至mult，完成hilo寄存器读写操作及其数据相关，完成相应除法指令及暂停

12.13更新完load/store部分，更新至点64

12.14 增添自制32位移位乘法器mymul.v，暂时没有经过调试

12.17 自制乘法器调试通过

12.20 添加lsa指令并通过测试

# 相关文件说明
lib：流水线使用相关组件，包括alu、mul、div等算数运算模块，decoder模块，寄存器阵列与内存模块

CTRL.v：暂停模块，进行流水线暂停控制信号的发送

IF.v：取指

ID.v：译码

EX.v：执行

MEM.v：访存

WB.v：回写
