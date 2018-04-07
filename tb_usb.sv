// Modelsim-ASE requires a timescale directive
`timescale 1 ns / 1 ps
module tb_usb;

   reg         clk  = 0;
   reg         rstf = 0;
   reg         dc_rstf;
   wire        dc_fspeed;
   wire        dc_lspeed;
   wire [ 1:0] dc_addr;
   wire        dc_csf;
   wire        dc_rdf;
   wire        dc_wrf;
   wire [15:0] dc_data_in;
   wire [15:0] dc_data_out;
   wire [15:0] dc_data;
   reg         dc_int0 = 0;
   reg         dc_int1 = 1;
   wire        dc_dack0f;
   wire        dc_dack1f;
   reg         start = 0;
   reg  [15:0] chip_id;
   reg  [15:0] scratch;
   wire        blinky;
   wire        int1;
   wire        lcd_on;
   wire        lcd_en;
   wire        lcd_rs;
   wire        lcd_rwf;
   wire [7:0]  lcd_data;
   wire [6:0]  hex0;
   wire [6:0]  hex1;
   wire [6:0]  hex2;
   wire [6:0]  hex3;
   wire [6:0]  hex4;
   wire [6:0]  hex5;
   wire [6:0]  hex6;
   wire [6:0]  hex7;

   // testbench
   parameter [0:4][15:0] SETUP_GET_DEV_DESC_PACKET  = '{16'h0008, 16'h0680, 16'h0100, 16'h0000, 16'h0020};
   parameter [0:4][15:0] SETUP_GET_CFG_DESC_PACKET  = '{16'h0008, 16'h0680, 16'h0200, 16'h0000, 16'h0020};
   parameter [0:4][15:0] SETUP_GET_CFG_PACKET       = '{16'h0008, 16'h0880, 16'h0000, 16'h0000, 16'h0020};
   parameter [0:4][15:0] SETUP_SET_ADDR_PACKET      = '{16'h0008, 16'h0580, 16'h0014, 16'h0000, 16'h0000};
   parameter [0:4][15:0] SETUP_SET_CFG_PACKET       = '{16'h0008, 16'h0980, 16'h0001, 16'h0000, 16'h0000};
   // TODO: add get device qualifier

   logic [15:0] addr=0, wdata=0, rdata=0;
   logic        cmd=0, write=0, read=0;
   logic [15:0] ep0out_reg=0;
   logic [15:0] ep0in_reg=0;
   logic [15:0] ep1out_reg=0;
   logic [15:0] ep1in_reg=0;
   logic [15:0] addr_reg=0;
   logic [15:0] mode_reg=0;
   logic [15:0] hwcfg_reg=0;
   logic [15:0] inten_reg=0;
   logic [15:0] scratch_reg=0;
   logic [15:0] intr_reg=0;
   logic [15:0] ep0ostat_reg=0;
   logic [15:0] ep0istat_reg=0;
   logic [15:0] ep1ostat_reg=0;
   logic [15:0] ep1istat_reg=0;
   //logic [15:0] ep0obuff_reg=0;
   logic [15:0] ep0ostatimage_reg=0;
   logic [15:0] ep0istatimage_reg=0;
   logic [15:0] ep1ostatimage_reg=0;
   logic [15:0] ep1istatimage_reg=0;
   logic [0:4][15:0] ep0obuff_reg=SETUP_GET_DEV_DESC_PACKET;
   int               i=0;
   int               len=5;


   usb u_usb (
        // System Interface
        .I_CLK       ( clk        ),      // Clock 50 MHz
        .I_RSTF      ( rstf       ),      // Reset (active low)
        .I_START     ( start      ),
        .O_CHIP_ID   ( chip_id    ),
        .O_SCRATCH   ( scratch    ),
        .O_BLINKY    ( blinky     ),
        .O_INT1_LED  ( int1       ),
        .O_LCD_ON    ( lcd_on     ),
        .O_LCD_EN    ( lcd_en     ),
        .O_LCD_RS    ( lcd_rs     ),
        .O_LCD_RWF   ( lcd_rwf    ),
        .O_LCD_DATA  ( lcd_data   ),
        .O_HEX0      ( hex0       ),
        .O_HEX1      ( hex1       ),
        .O_HEX2      ( hex2       ),
        .O_HEX3      ( hex3       ),
        .O_HEX4      ( hex4       ),
        .O_HEX5      ( hex5       ),
        .O_HEX6      ( hex6       ),
        .O_HEX7      ( hex7       ),
        // Device Controller Interface
        .O_DC_RSTF   ( dc_rstf    ),      // Reset the Device Controller (~800ns)
        .O_DC_FSPEED ( dc_fspeed  ),      // Full Speed, 0 = Enable, Z = Disable
        .O_DC_LSPEED ( dc_lspeed  ),      // Low Speed, 0 = Enable, Z = Disable
        .O_DC_ADDR   ( dc_addr    ),      // Address Bus, [1] = PIO bus of HC(=0) or DC(=1), [0] = command(=1) or data(=0) port
        .O_DC_CSF    ( dc_csf     ),      // Chip Select
        .O_DC_RDF    ( dc_rdf     ),      // Read Strobe
        .O_DC_WRF    ( dc_wrf     ),      // Write Strobe
        .IO_DC_DATA  ( dc_data    ),      // Data Bus (bidir)
        .I_DC_INT0   ( dc_int0    ),      // Interrupt 0, from Host Controller (unused)
        .I_DC_INT1   ( dc_int1    ),      // Interrupt 1, from Device Controller
        .O_DC_DACK0F ( dc_dack0f  ),      // DMA Acknowledge 0 (unused)
        .O_DC_DACK1F ( dc_dack1f  )       // DMA Acknowledge 1 (unused)
        );

   // 50 MHz clock
   always begin
      clk = 1'b0;
      #10ns; clk <= ~clk;
   end

   // reset (active low)
   initial begin
      rstf = 1'b0;
      #100ns; rstf = 1'b1;
   end

   // PIO transaction  (TODO: HANDLE CLEAR BUFFER)
   task bus_trans;
      forever begin
         // command phase
         wait(!dc_csf && !dc_wrf);
            $display("%g PIO Start", $time);
         @(posedge dc_wrf);
         if (dc_addr[0] == 1) begin
            cmd = ~cmd;
            addr = dc_data;
            $display("%g Command: %0h", $time, addr);
         end
         else begin
            $display("%g **Error: No command byte!", $time);
         end
         if (addr == 16'h61 | addr == 16'h70 | addr == 16'hF4) begin
            // code only
            continue;
         end
         else begin
            // data phase
            wait(!dc_csf && (!dc_wrf || !dc_rdf));
            if (!dc_wrf) begin
               if (addr == 16'hC2) begin      // write dword
                  $display("%g DWORD Write Detected", $time);
                  @(posedge dc_wrf); // word 0
                  wdata = dc_data;
                  $display("%g Received: %0h", $time, wdata);
                  write = ~write;
                  @(posedge dc_wrf); // word 1
                  wdata = dc_data;
                  $display("%g Received: %0h", $time, wdata);
                  write = ~write;
               end
               else if (addr == 16'h01) begin // write burst
                  $display("%g Burst Write  Detected", $time);
               end
               else begin                     // write word
                  $display("%g Write Detected", $time);
                  @(posedge dc_wrf);
                  wdata = dc_data;
                  $display("%g Received: %0h", $time, wdata);
                  write = ~write;
               end
            end
            else begin
               if (addr == 16'hC3) begin      // read dword
                  $display("%g DWORD Read Detected", $time);
                  read = ~read;
                  @(posedge dc_rdf); // read 0
                  $display("%g Sent: %0h", $time, rdata);
                  read = ~read;
                  @(posedge dc_rdf); // read 1
                  $display("%g Sent: %0h", $time, rdata);
               end
               else if (addr == 16'h10) begin // read burst
                  $display("%g Burst Read Detected", $time);
                  for (i=0; i<len; i++) begin
                     read = ~read;
                     @(posedge dc_rdf);
                     $display("%g Sent: %0h", $time, rdata);
                  end
               end
               else begin                     // read word
                  $display("%g Read Detected", $time);
                  read = ~read;
                  @(posedge dc_rdf);
                  $display("%g Sent: %0h", $time, rdata);
               end
            end // else: !if(!dc_wrf)
         end
         $display("%g PIO Complete", $time);
      end
   endtask

   assign dc_data = (!dc_rdf) ? rdata : 16'hZZZZ;

   // write registers
   always @(write) begin
      case (addr) inside
        16'h20: ep0out_reg  = wdata;
        16'h21: ep0in_reg   = wdata;
        16'h22: ep1out_reg  = wdata;
        16'h23: ep1in_reg   = wdata;
        [16'h24:16'h2F]: $display("%g EP (UNUSED) Register", $time);
        16'hB6: addr_reg    = wdata;
        16'hB8: mode_reg    = wdata;
        16'hBA: hwcfg_reg   = wdata;
        16'hC2: inten_reg   = wdata;
        16'hB2: scratch_reg = wdata;
        default: $display("%g Undefined Write Address", $time);
      endcase
   end

   // read registers
   always @(read) begin
      case (addr)
        16'h30: rdata = ep0out_reg;
        16'h31: rdata = ep0in_reg;
        16'h32: rdata = ep1out_reg;
        16'h33: rdata = ep1in_reg;
        16'h50: rdata = ep0ostat_reg;
        16'h51: rdata = ep0istat_reg;
        16'h52: rdata = ep1ostat_reg;
        16'h53: rdata = ep1istat_reg;
        16'hB7: rdata = addr_reg;
        16'hB9: rdata = mode_reg;
        16'hBB: rdata = hwcfg_reg;
        16'hC3: rdata = inten_reg;
        16'hB3: rdata = scratch_reg;
        16'hB5: rdata = 16'h3630;
        16'hC0: rdata = intr_reg;
        16'h10: rdata = ep0obuff_reg[i]; // TODO change this
        16'hD0: rdata = ep0ostatimage_reg;
        16'hD1: rdata = ep0istatimage_reg;
        16'hD2: rdata = ep1ostatimage_reg;
        16'hD3: rdata = ep1istatimage_reg;
        default: begin
           $display("%g Undefined Read Address", $time);
           rdata = 16'hDEAD;
        end
      endcase
   end

   always @(cmd) begin
      case (addr) inside
        // initialization registers
        16'h20: $display("%g EP0 OUT Register", $time);
        16'h21: $display("%g EP0 IN Register", $time);
        16'h22: $display("%g EP1 OUT  Register", $time);
        16'h23: $display("%g EP1 IN Register", $time);
        [16'h24:16'h2F]: $display("%g EP (UNUSED) Register", $time);
        16'hB6: $display("%g ADDR Register", $time);
        16'hB8: $display("%g MODE Register", $time);
        16'hBA: $display("%g HWCFG Register", $time);
        16'hC2: $display("%g INTR EN Register", $time);
        16'hB2: $display("%g SCRATCH Register", $time);
        16'h30: $display("%g EP0 OUT Register", $time);
        16'h31: $display("%g EP0 IN Register", $time);
        16'h32: $display("%g EP1 OUT Register", $time);
        16'h33: $display("%g EP1 IN Register", $time);
        16'h50: $display("%g EP0 OUT STATUS Register", $time);
        16'h51: $display("%g EP0 IN STATUS Register", $time);
        16'h52: $display("%g EP1 OUT STATUS Register", $time);
        16'h53: $display("%g EP1 IN STATUS Register", $time);
        16'h70: $display("%g EP0 OUT CLEAR Register", $time);
        16'h71: $display("%g EP0 IN CLEAR Register", $time);
        16'hB7: $display("%g ADDR Register", $time);
        16'hB9: $display("%g MODE Register", $time);
        16'hBB: $display("%g HWCFG Register", $time);
        16'hC3: $display("%g INT EN Register", $time);
        // dataflow registers
        16'h10: $display("%g EP0 OUT BUFF (Read) Register", $time);
        16'hD0: $display("%g EP0 OUT STATUS IMAGE Register", $time);
        16'hD1: $display("%g EP0 IN STATUS IMAGE Register", $time);
        16'hD2: $display("%g EP1 OUT STATUS IMAGE Register", $time);
        16'hD3: $display("%g EP1 IN STATUS IMAGE Register", $time);
        // general commands
        16'hB3: $display("%g SCRATCH Register", $time);
        16'hB5: $display("%g CHIP ID Register", $time);
        16'hC0: $display("%g INTR Register", $time);
      endcase
   end

   //logic [0:9][15:0] ep0buff = '{16'h08, 16'h00, 16'h00, 16'h01, 16'h02, 16'h03, 16'h04, 16'h05, 16'h06, 16'h07};
   //
   //always @(cmd) begin
   //   if (addr == 16'h10) begin
   //      for (int i=0; i<8; i++) begin
   //         ep0obuff_reg = ep0buff[i];
   //         @(read);
   //      end
   //   end
   //end


   // test stimulus
   initial begin
      $display("Starting Simulation");
      fork
         bus_trans;
      join_none
      @(mode_reg[0]);      // soft connect
      $display("%g Detected Soft Connect", $time);
      #40us;
      intr_reg = 1<<0;
      dc_int1 = 0;
      #500ns;
      dc_int1 = 1;
      $display("%g Interrupt Request: BUS RESET", $time);
      #40us;
      intr_reg = 1<<8;
      ep0ostat_reg = 16'h0034; // ep0 out full
      ep0obuff_reg = SETUP_GET_DEV_DESC_PACKET;
      dc_int1 = 0;
      #500ns;
      dc_int1 = 1;
      $display("%g Interrupt Request: EP0 OUT", $time);
      #30us
      intr_reg = 1<<8;
      ep0obuff_reg = SETUP_SET_ADDR_PACKET;
      dc_int1 = 0;
      #500ns;
      dc_int1 = 1;
      $display("%g Interrupt Request: EP0 OUT", $time);
      #30us
      intr_reg = 1<<8;
      ep0obuff_reg = SETUP_GET_CFG_DESC_PACKET;
      dc_int1 = 0;
      #500ns;
      dc_int1 = 1;
      $display("%g Interrupt Request: EP0 OUT", $time);
      #30us
      intr_reg = 1<<8;
      ep0obuff_reg = SETUP_GET_CFG_PACKET;
      dc_int1 = 0;
      #500ns;
      dc_int1 = 1;
      $display("%g Interrupt Request: EP0 OUT", $time);
      #30us
      intr_reg = 1<<8;
      ep0obuff_reg = SETUP_GET_CFG_PACKET;
      dc_int1 = 0;
      #500ns;
      dc_int1 = 1;
      $display("%g Interrupt Request: EP0 OUT", $time);
      #30us
      intr_reg = 1<<8;
      ep0obuff_reg = SETUP_SET_CFG_PACKET;
      dc_int1 = 0;
      #500ns;
      dc_int1 = 1;
      $display("%g Interrupt Request: EP0 OUT", $time);
      #30us
      dc_int1 = 0;
      #500ns;
      dc_int1 = 1;
      //#20us;
      //intr_reg = 1<<0;
      //dc_int1 = ~dc_int1;
      //$display("%g Interrupt Request: BUS RESET", $time);

      //#1500ns;
      ////dc_int1 = 1'b1;
      //start = 1;
      //#200ns;
      ////dc_int1 = 1'b0;
      //start = 0;
      //#100ms;
      //#1ms;
      #20us;
      $finish;
   end

endmodule
