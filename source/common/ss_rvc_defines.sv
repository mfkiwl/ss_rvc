//-----------------------------------------------------------------------------
// Title            : ss_rvc_defines
// Project          : ss_rvc
//-----------------------------------------------------------------------------
// File             : ss_rvc_defines.sv
// Original Author  : Amichai Ben-David
// Created          : 7/2021
//-----------------------------------------------------------------------------
// Description :
//-----------------------------------------------------------------------------
`ifndef ss_rvc_defines
`define ss_rvc_defines

`define  RVC_MSFF(q,i,clk)             \
         always_ff @(posedge clk)       \
            q<=i;

`define  RVC_EN_MSFF(q,i,clk,en)       \
         always_ff @(posedge clk)       \
            if(en) q<=i;

`define  RVC_RST_MSFF(q,i,clk,rst)     \
         always_ff @(posedge clk) begin \
            if (rst) q <='0;            \
            else     q <= i;            \
         end
        
`define  RVC_RST_VAL_MSFF(q,i,clk,rst,val) \
         always_ff @(posedge clk) begin    \
            if (rst) q <= val;             \
            else     q <= i;               \
         end

`define  RVC_EN_RST_MSFF(q,i,clk,en,rst)\
         always_ff @(posedge clk)       \
            if (rst)    q <='0;         \
            else if(en) q <= i;

`define  RVC_EN_RST_VAL_MSFF(q,i,clk,en,rst,val)\
         always_ff @(posedge clk) begin \
            if (rst)    q <=val;        \
            else if(en) q <= i; end

`define  RVC_ENCODER(encoded , decoded )\
	always_comb begin\
		encoded = '0 ;\
		for (int i = 0 ; i <$bits(decoded) ;i++) begin\
			if (decoded[i])\
				encoded = i ;\
		end\
	end

`define  RVC_DECODER(decoded , encoded )\
	always_comb begin\
		decoded = '0;\
        decoded[encoded] = 1'b1;\
	end

`define RVC_SX(in,sz) {{sz-$bits(in){in[$bits(in)-1]}},(in)}

`endif // ss_rvc_defines

