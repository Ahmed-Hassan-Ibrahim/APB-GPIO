module GPIO(
    input                  pclk,       // Clock signal
    input                  preset_n,   // Active Low Reset

    input                  psel_i,     // Peripheral select signal
    input                  penable_i,  // Peripheral enable signal
    input        [3:0]     paddr_i,    // Peripheral address signal
    input                  pwrite_i,   // Write enable signal (1-> writing to slave, 0 -> reading from slave)
    input        [7:0]     pwdata_i,   // Write data input
    output reg   [7:0]     prdata_o,   // Read data output
    output                 pready_o,   // Ready signal from slave    
    input        [7:0]     gpio_i,     // GPIO input
    output reg   [7:0]     gpio_o,     // GPIO output
    output reg   [7:0]     gpio_oe     // GPIO output enable
);

localparam  DIRECTION = 0,  // Address for direction register
            OUTPUT    = 1,  // Address for output register
            INPUT     = 2;  // Address for input register

// Control Registers
logic [7:0] dir_reg,  // Direction register (0 -> Input, 1 -> Output)
            out_reg,  // Output register
            in_reg;   // Input register

assign pready_o = 1'b1;  // Always ready

/* APB Writes */
// APB write to Direction register
always @(posedge pclk,negedge preset_n)
if(psel_i & penable_i & pwrite_i) begin
    if (paddr_i == DIRECTION) begin
        if(!preset_n)
            dir_reg <= {8{1'b0}};
        else 
            dir_reg <= pwdata_i;
    end    
    if(paddr_i == OUTPUT) begin
        if(!preset_n) 
            out_reg <= {8{1'b0}};
        else 
            out_reg <= pwdata_i; 
    end
end

/* APB Reads */
always @(posedge pclk)
if(psel_i & penable_i)begin
    case (paddr_i)
        DIRECTION: prdata_o <= dir_reg;
        OUTPUT   : prdata_o <= out_reg;
        INPUT    : prdata_o <= in_reg;
        default  : prdata_o <= {8{1'b0}};
    endcase
end

always @(posedge pclk)
in_reg <= gpio_i;  // Update input register with GPIO input

// Drive out_reg value onto GPIO output when gpio_oe is enabled
always @(posedge pclk)
if (gpio_oe) begin
    for (int n=0; n<8; n++)
        gpio_o[n] <= out_reg[n];
end  

// Update gpio_oe based on dir_reg
always @(posedge pclk)
for (int n=0; n<8; n++)
    gpio_oe[n] <= dir_reg[n];            

endmodule

module apb_GPIO_master(
    input               pclk,
    input               preset_n,  // Active Low Reset

    input        [1:0]  ctrl_i,    // Control signals (2'b00 - NOP, 2'b01 - READ, 2'b11 - WRITE)
    
    output              psel_o,
    output              penable_o,
    input reg    [3:0]  paddr_tb,
    output       [3:0]  paddr_o,
    output              pwrite_o,  // Write enable signal (1-> writing to slave, 0 -> reading from slave)
    output       [7:0]  pwdata_o,
    input reg    [7:0]  prdata_i,  // Read data input
    input               pready_i   // Ready signal from slave      
);

// Standard APB protocol states
localparam IDLE     = 2'b00;
localparam SETUP    = 2'b01;
localparam ACCESS   = 2'b11;

wire apb_state_setup;
wire apb_state_access;

reg next_pwrite;
reg pwrite_q;
reg [7:0] next_rdata;
reg [7:0] rdata_q;

reg [1:0] state_q, next_state;

always @(posedge pclk or negedge preset_n)
if(~preset_n)
    state_q <= IDLE;
else
    state_q <= next_state;

always @(*) begin
    next_pwrite = pwrite_q;
    next_rdata = rdata_q;
    case (state_q)
    IDLE:
        if(ctrl_i[0]) begin
            next_state = SETUP;
            next_pwrite = ctrl_i[1];
        end else begin
            next_state = IDLE;
        end
    SETUP: next_state = ACCESS;
    ACCESS:
        if(pready_i) begin
            if(~pwrite_q)
                next_rdata = prdata_i;
            next_state = IDLE;
        end else    
            next_state = ACCESS;      
    default: next_state = IDLE;
    endcase
end

assign apb_state_access = (state_q == ACCESS);
assign apb_state_setup = (state_q == SETUP);

assign psel_o = apb_state_setup | apb_state_access;
assign penable_o = apb_state_access;

assign paddr_o =  paddr_tb;

always@(posedge pclk or negedge preset_n)
if(~preset_n)
    pwrite_q <= 1'b0;
else
    pwrite_q <= next_pwrite; 

assign pwrite_o = pwrite_q;

assign pwdata_o = 8'b10101010;

always @(posedge pclk or negedge preset_n) 
if(~preset_n)
    rdata_q <= 8'h0;
else
    rdata_q <= next_rdata;

endmodule
