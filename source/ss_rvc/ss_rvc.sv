//-----------------------------------------------------------------------------
// Title            : 
// Project          : 
//-----------------------------------------------------------------------------
// File             : 
// Original Author  : 
// Code Owner       : 
// Created          : 7/2021
//-----------------------------------------------------------------------------
// Description :
// ----5 PipeStage----
// 1) Q100H Instruction Fetch   - Send Pc to Instruction Memory, Calculate next PC.
// 2) Q101H Instruction Decode  - Set thye Ctrl bits, read from register file.
// 3) Q102H Excecute            - Calculate the Imm<->Reg | Reg<->Reg in the ALU.
// 4) Q103H Mem Access          - Load/Store data from/to data memory
// 5) Q104H Writeback           - mux the data from Load with ALU output. write to register file.
//------------------------------------------------------------------------------
// Modification history :
//
//
//------------------------------------------------------------------------------

`include "ss_rvc_defines.sv"
module ss_rvc 
    import ss_rvc_pkg::*;  
    (
    input  logic          QClk,
    input  logic          RstQnnnH,
    input  logic          RstPcQnnnH,
    //Instruction Memory
    output t_xlen         PcQ100H,
    input  t_instruction  InstructionQ101H,
    //Data Memory
    output t_xlen         AddressDmQ103H,
    output t_xlen         WrDataDmQ103H,
    output logic          RdEnDmQ103H,
    output logic          WrEnDmQ103H,
    input  t_xlen         RdDataDmQ104H
    );

t_xlen      PrePcQ100H;
t_xlen      NextPcQ100H;
t_xlen      PcQ101H;
logic       FreezePcQ101H;

// Decode
t_opcodes   OpcodeQ101H;
logic [2:0] Funct3Q101H;
logic [6:0] Funct7Q101H;
logic       I_ImmQ101H , I_ImmQ101H;
logic       S_ImmQ101H , S_ImmQ101H;

// Forwarding and Hazards Rd/Wr Register
logic [4:0] RegDstQ101H  , RegDstQ102H  , RegDstQ103H , RegDstQ104H;
logic [4:0] RegSrc1Q101H , RegSrc1Q102H;
logic [4:0] RegSrc2Q101H , RegSrc2Q102H;

// Ctrl Bits
logic       CtrlOpQ101H         ;
t_alu_op    CtrlAluOpQ101H      , CtrlAluOpQ102H      ;
logic       CtrlStoreQ101H      , CtrlStoreQ102H      ;
logic       CtrlOpImmQ101H      , CtrlOpImmQ102H      ;
logic       CtrlImmTypeQ101H    , CtrlImmTypeQ102H    ;
logic       CtrlTwosComplQ101H  , CtrlTwosComplQ102H  ;
logic       CtrlLoadQ101H       , CtrlLoadQ102H       , CtrlLoadQ103H                       ;
logic       CtrlRegWrEnQ101H    , CtrlRegWrEnQ102H    , CtrlRegWrEnQ103H , CtrlRegWrEnQ104H ;



//////////////////////////////////////////////////////////////////////////////////////////////////
//   _____  __     __   _____   _        ______          ____    __    ___     ___    _    _ 
//  / ____| \ \   / /  / ____| | |      |  ____|        / __ \  /_ |  / _ \   / _ \  | |  | |
// | |       \ \_/ /  | |      | |      | |__          | |  | |  | | | | | | | | | | | |__| |
// | |        \   /   | |      | |      |  __|         | |  | |  | | | | | | | | | | |  __  |
// | |____     | |    | |____  | |____  | |____        | |__| |  | | | |_| | | |_| | | |  | |
//  \_____|    |_|     \_____| |______| |______|        \___\_\  |_|  \___/   \___/  |_|  |_|
//
//////////////////////////////////////////////////////////////////////////////////////////////////
// Calculate the Next PC (Program Counter)
// have a Q101H Version of PC incase of Load Hazard Detection - we need to re-send the Previes PC
//////////////////////////////////////////////////////////////////////////////////////////////////
assign NextPcQ100H = PcQ100H + 32'h4;
`RVC_EN_RST_MSFF( PrePcQ100H, NextPcQ100H, QClk, FreezePcQ101H, (RstQnnnH || RstPcQnnnH) )
`RVC_EN_MSFF(     PcQ101H   , PrePcQ100H , QClk, FreezePcQ101H)
//Incase of FreezePcQ101H - re-send the Old Pc (Q101H) so same Instruction will be read again.
assign PcQ100H  = FreezePcQ101H ? PcQ101H : PrePcQ100H; // common case - PcQ100H = PrePcQ100H

//////////////////////////////////////////////////////////////////////////////////////////////////
//   _____  __     __   _____   _        ______          ____    __    ___    __   _    _ 
//  / ____| \ \   / /  / ____| | |      |  ____|        / __ \  /_ |  / _ \  /_ | | |  | |
// | |       \ \_/ /  | |      | |      | |__          | |  | |  | | | | | |  | | | |__| |
// | |        \   /   | |      | |      |  __|         | |  | |  | | | | | |  | | |  __  |
// | |____     | |    | |____  | |____  | |____        | |__| |  | | | |_| |  | | | |  | |
//  \_____|    |_|     \_____| |______| |______|        \___\_\  |_|  \___/   |_| |_|  |_|
//
//////////////////////////////////////////////////////////////////////////////////////////////////
// 
//
//////////////////////////////////////////////////////////////////////////////////////////////////

//==================
//     Decode
//==================
assign OpcodeQ101H     = InstructionQ101H[6:0];
assign RdQ101H         = InstructionQ101H[11:7];
assign Funct3Q101H     = InstructionQ101H[14:12];
assign RegSrc1Q101H    = InstructionQ101H[19:15];
assign RegSrc2Q101H    = InstructionQ101H[24:20];
assign Funct7Q101H     = InstructionQ101H[31:25];
assign I_ImmQ101H      = InstructionQ101H[31:20];
assign S_ImmQ101H      ={InstructionQ101H[31:20],InstructionQ101H[11:7]};

always_comb begin : set_the_ctrl_bits
    //supporting 4 kinds of Opcodes:
    CtrlLoadQ101H      = (OpcodeQ101H == OP_LOAD);
    CtrlStoreQ101H     = (OpcodeQ101H == OP_STORE);
    CtrlOpImmQ101H     = (OpcodeQ101H == OP_OPIMM);
    CtrlOpQ101H        = (OpcodeQ101H == OP_OP);
    //Supporting 2 kinds of Immidaites
    CtrlImmTypeQ101H   = (OpcodeQ101H == OP_STORE) ? S_TYPE :
                                                     I_TYPE ;//OP_OPIMM || OP_LOAD
    //select the ALU input as Reg<->Imm. (Imm in AluIn2)
    CtrlAluInImmQ101H  = CtrlOpImmQ101H || CtrlLoadQ101H || CtrlStoreQ101H;
    //Opcodes that write to the regiser file.
    CtrlRegWrEnQ101H   = CtrlOpImmQ101H || CtrlLoadQ101H || CtrlOpQ101H;
    //the ALU operation
    CtrlAluOpQ101H     = Funct3Q101H;
    if (CtrlLoadQ101H || CtrlStoreQ101H ) begin : alu_should_add
        CtrlAluOpQ101H = ADD; //in this case we dont use the Funct3Q101H as the ALU OP ctrl.
    end
    //incase of Substaction - need to use Twos Compliment.
    CtrlTwosComplQ101H = CtrlOpQ101H && (Funct7Q101H == 7'b010_0000)
end

//==================
//  Register File
//==================
`RVC_MSFF( RegisterQnnnH, NextRegisterQ104H, QClk)
//==================
always_comb begin 
    RegRdData1Q101H = RegisterQnnnH[RegSrc1Q101H];
    RegRdData2Q101H = RegisterQnnnH[RegSrc2Q101H]; 
    //Incase if the Q104H  Write Matches the Q101H Read.
    if( (RegSrc1Q101H == RegDstQ104H) && (RegSrc1Q101H != 5'b0) begin
        RegRdData1Q101H = RegWrDataQ104H;
    end
    if( (RegSrc2Q101H == RegDstQ104H) && (RegSrc2Q101H != 5'b0) begin
        RegRdData2Q101H = RegWrDataQ104H;
    end
end

//====================================
//  Sample the Q101H->Q102H signals
//====================================
//Sample Rd Data and Instruction for Immidtea
`RVC_MSFF( RegRdData1Q102H    , RegRdData1Q101H     , QClk)
`RVC_MSFF( RegRdData2Q102H    , RegRdData2Q101H     , QClk)
`RVC_MSFF( I_ImmQ102H         , I_ImmQ101H          , QClk)
`RVC_MSFF( S_ImmQ102H         , S_ImmQ101H          , QClk)
//Sample Register Bits
`RVC_MSFF( RegDstQ102H        , RegDstQ101H         , QClk)
`RVC_MSFF( RegSrc1Q102H       , RegSrc1Q101H        , QClk)
`RVC_MSFF( RegSrc2Q102H       , RegSrc2Q101H        , QClk)
//Sample Ctrl Bits
`RVC_MSFF( CtrlAluOpQ102H     , CtrlAluOpQ101H      , QClk)
`RVC_MSFF( CtrlLoadQ102H      , CtrlLoadQ101H       , QClk)
`RVC_MSFF( CtrlStoreQ102H     , CtrlStoreQ101H      , QClk)
`RVC_MSFF( CtrlOpImmQ102H     , CtrlOpImmQ101H      , QClk)
`RVC_MSFF( CtrlImmTypeQ102H   , CtrlImmTypeQ101H    , QClk)
`RVC_MSFF( CtrlRegWrEnQ102H   , CtrlRegWrEnQ101H    , QClk)
`RVC_MSFF( CtrlTwosComplQ102H , CtrlTwosComplQ101H  , QClk)

//////////////////////////////////////////////////////////////////////////////////////////////////
//    _____  __     __   _____   _        ______          ____    __    ___    ___    _    _ 
//   / ____| \ \   / /  / ____| | |      |  ____|        / __ \  /_ |  / _ \  |__ \  | |  | |
//  | |       \ \_/ /  | |      | |      | |__          | |  | |  | | | | | |    ) | | |__| |
//  | |        \   /   | |      | |      |  __|         | |  | |  | | | | | |   / /  |  __  |
//  | |____     | |    | |____  | |____  | |____        | |__| |  | | | |_| |  / /_  | |  | |
//   \_____|    |_|     \_____| |______| |______|        \___\_\  |_|  \___/  |____| |_|  |_|
//                                                                                           
//////////////////////////////////////////////////////////////////////////////////////////////////
// 
//
//////////////////////////////////////////////////////////////////////////////////////////////////
always_comb begin : select_alu_inputs
//================================================
//  Defuatlt R-Type Reg<->Reg Operation
//================================================
    AluIn1Q102H = RegRdData1Q102H;  //defualt 
    AluIn2Q102H = RegRdData2Q102H;  //defualt
//================================================
//  Forwording Unit
//================================================
    if(RegSrc1Q102H != '0) begin //forwording for Src '1'
        if(RegSrc1Q102H == RegWrDstQ104H)  AluIn1Q102H = AluOutQ104H;
        if(RegSrc1Q102H == RegWrDstQ103H)  AluIn1Q102H = AluOutQ103H; //prioraty for Q103H
    end //if RegSrc1Q102H
    if(RegSrc2Q102H != '0) begin //forwording for Src '2'
        if(RegSrc2Q102H == RegWrDstQ104H)  AluIn2Q102H = AluOutQ104H;
        if(RegSrc2Q102H == RegWrDstQ103H)  AluIn2Q102H = AluOutQ103H; //prioraty for Q103H
    end // if RegSrc2Q102H
//================================================
//  Incase of R-Type SUB - need twos Compliment the 
//================================================
    if(CtrlTwosComplQ102H && (CtrlAluOpQ102H==ADD)) begin //ADD & SUB have the same Funct3 OP.
        AluIn2Q102H = (~AluIn2Q102H) + 1'b1;
    end
//================================================
//  Incase of I-Type/S-Type AluIn2  gets the Immideate Value
//================================================
    unique casez (CtrlImmTypeQ102H)
        I_TYPE  : ImmQ102H = `RVC_SX(I_ImmQ102H, XLEN);
        S_TYPE  : ImmQ102H = `RVC_SX(S_ImmQ102H, XLEN);
        default : ImmQ102H = `RVC_SX(I_ImmQ102H, XLEN);
    endcase
     if(CtrlLoadQ102H || CtrlStoreQ102H || CtrlOpImmQ102H) begin : imm_type_alu_in
        AluIn2Q102H = ImmQ102H; //incase of not a Reg<->Reg Type use the Imm Value and not the forwording/Register Read
    end //if (CtrlLoadQ102H || CtrlStoreQ102H || CtrlOpImmQ102H
end// always_comb

logic [4:0] ShamtQ102H;
assign ShamtQ102H = AluIn2Q102H[4:0];
always_comb begin : alu_operation
    unique casez (CtrlAluOpQ102H) 
        //use adder
        ADD     : AluOutQ102H = AluIn1Q102H +   AluIn2Q102H                          ;//ADD
        SLT     : AluOutQ102H = {31'b0, $signed(AluIn1Q102H) < $signed(AluIn2Q102H)} ;//SLT
        SLTU    : AluOutQ102H = {31'b0, AluIn1Q102H < AluIn2Q102H}                   ;//SLTU
        //shift
        SLL     : AluOutQ102H = AluIn1Q102H << ShamtQ102H                            ;//SLL
        SRL     : AluOutQ102H = AluIn1Q102H >> ShamtQ102H                            ;//SRL
        //bit wise opirations
        XOR     : AluOutQ102H = AluIn1Q102H ^ AluIn2Q102H                            ;//XOR
        OR      : AluOutQ102H = AluIn1Q102H | AluIn2Q102H                            ;//OR
        AND     : AluOutQ102H = AluIn1Q102H & AluIn2Q102H                            ;//AND
        default : AluOutQ102H = 32'b0                                                ;
    endcase
end //always_comb alu_operation

// Sample Register Bits
`RVC_MSFF( RegDstQ103H   , RegDstQ102H , QClk)
`RVC_MSFF( AluOutQ103H   , AluOutQ102H , QClk)
`RVC_MSFF( WrDataDmQ103H , AluIn2Q102H , QClk)
//Sample Ctrl Bits
`RVC_MSFF( CtrlLoadQ103H      , CtrlLoadQ201H       , QClk)
`RVC_MSFF( CtrlRegWrEnQ103H   , CtrlRegWrEnQ102H    , QClk)
//////////////////////////////////////////////////////////////////////////////////////////////////
//   _____  __     __   _____   _        ______          ____    __    ___    ____    _    _ 
//  / ____| \ \   / /  / ____| | |      |  ____|        / __ \  /_ |  / _ \  |___ \  | |  | |
// | |       \ \_/ /  | |      | |      | |__          | |  | |  | | | | | |   __) | | |__| |
// | |        \   /   | |      | |      |  __|         | |  | |  | | | | | |  |__ <  |  __  |
// | |____     | |    | |____  | |____  | |____        | |__| |  | | | |_| |  ___) | | |  | |
//  \_____|    |_|     \_____| |______| |______|        \___\_\  |_|  \___/  |____/  |_|  |_|
//
//////////////////////////////////////////////////////////////////////////////////////////////////
// 
//
//////////////////////////////////////////////////////////////////////////////////////////////////
assign AddressDmQ103H   = AluOutQ103H;
assign RdEnDmQ103H      = CtrlLoadQ102H;
assign WrEnDmQ103H      = CtrlStoreQ102H;

// Sample Register Bits
`RVC_MSFF( RegDstQ104H      , RegDstQ103H       , QClk)
`RVC_MSFF( AluOutQ104H      , AluOutQ103H       , QClk)
//Sample Ctrl Bits
`RVC_MSFF( CtrlLoadQ104H    , CtrlLoadQ103H     , QClk)
`RVC_MSFF( CtrlRegWrEnQ104H , CtrlRegWrEnQ103H  , QClk)
//////////////////////////////////////////////////////////////////////////////////////////////////
//    ____  __     __   _____   _        ______          ____    __    ___    _  _     _    _ 
//  / ____| \ \   / /  / ____| | |      |  ____|        / __ \  /_ |  / _ \  | || |   | |  | |
// | |       \ \_/ /  | |      | |      | |__          | |  | |  | | | | | | | || |_  | |__| |
// | |        \   /   | |      | |      |  __|         | |  | |  | | | | | | |__   _| |  __  |
// | |____     | |    | |____  | |____  | |____        | |__| |  | | | |_| |    | |   | |  | |
//  \_____|    |_|     \_____| |______| |______|        \___\_\  |_|  \___/     |_|   |_|  |_|
//
//////////////////////////////////////////////////////////////////////////////////////////////////
// 
//
//////////////////////////////////////////////////////////////////////////////////////////////////
always_comb begin : write_back_to_register
    NextRegisterQ104H = RegisterQnnnH;
    if (CtrlRegWrEnQ104H) begin
        NextRegisterQ104H[RegDstQ104H] = CtrlLoadQ104H ? RdDataDmQ104H : // Data loaded from D_MEM
                                                         AluOutQ104H;    // Data Calculated in ALU.
    end
    NextRegisterQ104H[0] = 32'b0;
end //always_comb write_back_to_register

endmodule
