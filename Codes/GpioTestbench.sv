module apb_slave_tb();
    reg             pclk;        // Clock signal
    reg             preset_n;    // Active low reset

    reg   [1:0]     ctrl_i;      // Control signals (2'b00 - NOP, 2'b01 - READ, 2'b11 - WRITE) - drives apb output signals

    wire            psel_o;      // Peripheral select signal
    wire            penable_o;   // Peripheral enable signal
    reg  [3:0]      paddr_tb;    // Testbench peripheral address
    wire            pwrite_o;    // Write enable signal (1-> writing to slave, 0 -> reading from slave)
    wire  [7:0]     pwdata_o;    // Write data output

    reg   [7:0]     prdata_i;    // Read data input
    wire            pready_i;    // Ready signal from slave   

    reg   [7:0]     gpio_i;      // GPIO input
    reg   [7:0]     gpio_o;      // GPIO output
    reg   [7:0]     gpio_oe;     // GPIO output enable  

    // Clock Implementation
    always begin
        pclk = 1'b0;
        #5;
        pclk = 1'b1;
        #5;
    end

    // Instantiate APB master and GPIO modules
    apb_GPIO_master APB_MASTER(
        .pclk(pclk),
        .preset_n(preset_n),
        .ctrl_i(ctrl_i),
        .psel_o(psel_o),
        .penable_o(penable_o),
        .paddr_tb(paddr_tb),
        .pwrite_o(pwrite_o),
        .pwdata_o(pwdata_o),
        .prdata_i(prdata_i),
        .pready_i(pready_i)
    );
    GPIO gpio(
        .pclk(pclk),
        .preset_n(preset_n),
        .psel_i(psel_o),
        .penable_i(penable_o),
        .paddr_i(paddr_tb),
        .pwrite_i(pwrite_o),
        .pwdata_i(pwdata_o),
        .prdata_o(prdata_i),
        .pready_o(pready_i),
        .gpio_i(gpio_i),
        .gpio_o(gpio_o),
        .gpio_oe(gpio_oe)
    );
    
    initial begin
        gpio_i = 8'b11111110;  // Initialize GPIO input
        preset_n = 1'b0;        // Assert reset
        ctrl_i = 2'b00;         // NOP
        repeat (2) `CLK;        // Wait for a couple of clock cycles
        preset_n = 1'b1;        // De-assert reset
        repeat (2) `CLK;        // Wait for a couple of clock cycles

        //===========Test(1)=============================================================================
        // Read transaction
        paddr_tb = 4'b0010;     // Set testbench peripheral address
        ctrl_i = 2'b01;         // Read
        `CLK;                   // Wait for a clock cycle
        ctrl_i = 2'b00;         // NOP
        repeat (4) `CLK;        // Wait for a few clock cycles

        //===========Test(2)=============================================================================
        // Write transactions
        paddr_tb = 4'b0000;     // Set testbench peripheral address
        ctrl_i = 2'b11;         // Write
        `CLK;                   // Wait for a clock cycle
        ctrl_i = 2'b00;         // NOP
        repeat (4) `CLK;        // Wait for a few clock cycles

        paddr_tb = 4'b0001;     // Set testbench peripheral address
        ctrl_i = 2'b11;         // Write
        `CLK;                   // Wait for a clock cycle
        ctrl_i = 2'b00;         // NOP
        repeat (4) `CLK;        // Wait for a few clock cycles

        $finish();              // Finish simulation
    end

    // Dump waveforms
    initial begin
        $dumpfile("abp_master.vcd");
        $dumpvars(2,apb_slave_tb);
    end

endmodule
