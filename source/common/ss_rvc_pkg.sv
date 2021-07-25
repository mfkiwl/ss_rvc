//-----------------------------------------------------------------------------
// Title         : 
// Project       : 
//-----------------------------------------------------------------------------
// File          : 
// Author        : Amichai Ben-David
// Created       : 7/2020
//-----------------------------------------------------------------------------
// Description :
// parameters and struct used in ss_rvc
//-----------------------------------------------------------------------------

package ss_rvc_pkg;


parameter XLEN = 32;

typedef logic [XLEN-1:0] t_xlen;

typedef enum logic {
    I_TYPE  =   1'b0;
    S_TYPE  =   1'b1;
} t_imm_type

typedef enum logic {
    ADD  =   3'b000;
    SLL  =   3'b001;
    SLT  =   3'b010;
    SLTU =   3'b011;
    XOR  =   3'b100;
    SRL  =   3'b101;
    OR   =   3'b110;
    AND  =   3'b111;
} t_alu_op

typedef enum logic {
    OP_LOAD   =   7'b0000011;
    OP_STORE  =   7'b0100011;
    OP_OPIMM  =   7'b0010011;
    OP_OP     =   7'b0110011;
} t_opcodes


endpackage // ss_rvc_pkg

