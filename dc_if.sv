import d13_pkg::*;

module dc_if (
               // System Interface
               input         I_CLK,      // Clock 50 MHz
               input         I_RSTF,     // Reset (active low)
               input         I_START,    // Start Test
               output [15:0] O_CHIP_ID,  // Chip ID
               output [15:0] O_SCRATCH,  // Scratch content
               output [15:0] O_INTR,     // Interrupt Register
               output [31:0] O_DEBUG,    // Interrupt Register
               // Bus Interface
               output        O_DC_RSTF,  // Reset the Device Controller (~800ns)
               output [ 1:0] O_DC_ADDR,  // Address Bus, [1] = PIO bus of HC (0) or DC (1), [0] = command (1) or data (0) port
               output        O_DC_CSF,   // Chip Select
               output        O_DC_RDF,   // Read Strobe
               output        O_DC_WRF,   // Write Strobe
               inout  [15:0] IO_DC_DATA, // Data Bus (bidir)
               input         I_DC_INT1,  // Interrupt 1, from Device Controller
               output [31:0] O_RDATA,    // Read Data from Bus Interface
               output        O_DATA_RDY, // Data ready from USB
               output        O_DONE
              );

`include "d13_parameters.svh"

   // addresses
   parameter WR_ADDR_SCRATCH     = 8'hB2;
   parameter RD_ADDR_SCRATCH     = 8'hB3;
   parameter RD_ADDR_CHIP_ID     = 8'hB5;
   parameter SCRATCH_DATA        = 16'h55AA;
   parameter MODE_DATA           = 16'h0009;  // Bit[3] = Interrupt Enable, Bit[0] = Soft Connect
   parameter EPCFG_TC            = 16;
   parameter SETUP_FIFO_WORDS    = 5;         // setup packet (8 bytes) + packet length (2 bytes)
   parameter SETUP_SIZE_BYTES    = 8;         // setup packet (8 bytes)
   parameter DEV_DESC_SIZE_BYTES = 18;
   parameter DEV_DESC_FIFO_WORDS = 9+1;
   parameter CFG_DESC_SIZE_BYTES = 9;
   parameter CFG_DESC_FIFO_WORDS = 5+1;
   parameter IFC_DESC_SIZE_BYTES = 9;
   parameter IFC_DESC_FIFO_WORDS = 5+1;
   parameter EP_DESC_SIZE_BYTES  = 7;
   parameter EP_DESC_FIFO_WORDS  = 4+1;

   logic [0:15][7:0] EPCFG_ADDR = '{
                                    DC_WEP0OUT_CONFIG, // Control OUT Configuration
                                    DC_WEP0IN_CONFIG,  // Control IN Configuration
                                    DC_WEP1OUT_CONFIG, // Endpoint 1 OUT Configuration
                                    DC_WEP1IN_CONFIG,  // Endpoint 1 IN Configuration
                                    DC_WEPNUM_CONFIG,  // Endpoint 2-7 OUT/IN Starting Index (0x24)
                                    8'h25, 8'h26, 8'h27, 8'h28, 8'h29, 8'h2A, 8'h2B, 8'h2C, 8'h2D, 8'h2E, 8'h2F // Remaining EP
                                    };

   logic [0:15][15:0] EPCFG_DATA = '{
                                     16'h0083, // EP0 Config, Bit[7] = FIFO Enable, Bit[6] = Direction OUT, Bit[3:0] = 64 bytes
                                     16'h00C3, // EP0 Config, Bit[7] = FIFO Enable, Bit[6] = Direction IN,  Bit[3:0] = 64 bytes
                                     16'h0083, // EP1 Config, Bit[7] = FIFO Enable, Bit[6] = Direction OUT, Bit [5] = Double-Buffer, Bit[3:0] =  0 = 8 bytes, 3 = 64 bytes
                                     16'h00E3, // EP1 Config, Bit[7] = FIFO Enable, Bit[6] = Direction IN,  Bit [5] = Double-Buffer, Bit[3:0] =  0 = 8 bytes, 3 = 64 bytes
                                     16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0 // Remaining EP
                                     };


   logic [0:8][15:0] DEV_DESC = '{
                                   16'h0112, // descriptor type (1=device), length = 18 bytes (12h)
                                   16'h0110, // bcd USB 2.0 (trying USB 1.1 instead and No Device Qualifier... init's quicker)!!!
                                   16'h0000, // device subclass, device class
                                   16'h4000, // max packet size ep0, device protocol
                                   16'h0471, // vendor id
                                   16'h0000, // product id (chip id, see below)
                                   16'h0100, // bcd Device
                                   16'h0000, // product, manufacturer
                                   16'h0100  // number of configurations, serial number
                                   };

   logic [8:0][15:0] DEV_DESC_REV;
   generate
      genvar         i;
      for (i=0; i<9; i++) begin : gen0
         assign DEV_DESC_REV[i] = DEV_DESC[i];
      end
   endgenerate

   // byte form
   parameter [0:31][7:0] CFG_DESC_BYTES = '{
                                            // config
                                            8'h09,    // length = 9 bytes
                                            8'h02,    // descriptor type (2=config)
                                            8'h20,    // total length (9+9+7*2=32)
                                            8'h00,
                                            8'h01,    // number of interfaces
                                            8'h01,    // config value
                                            8'h00,    // configuration
                                            8'hC0,    // attributes
                                            8'h32,    // max power
                                            // interface
                                            8'h09,    // length = 9 bytes
                                            8'h04,    // descriptor type (4=interface)
                                            8'h00,    // interface number
                                            8'h00,    // alternate setting
                                            8'h02,    // number of endpoints
                                            8'hFF,    // interface class (00h or FFh)
                                            8'h00,    // interface subclass
                                            8'h00,    // interface protocol
                                            8'h00,    // interface
                                            // endpoint 1 bulk out
                                            8'h07,   // length = 7 bytes
                                            8'h05,   // descriptor type (5=endpoint)
                                            8'h01,   // endpoint address (01h=OUT)
                                            8'h02,   // attribute (bulk)
                                            8'h02,   // max packet size
                                            8'h00,
                                            8'h00,   // interval
                                            // endpoint 1 bulk in
                                            8'h07,   // length = 7 bytes
                                            8'h05,   // descriptor type (5=endpoint)
                                            8'h81,   // endpoint address (81h=IN)
                                            8'h02,   // attribute (bulk)
                                            8'h02,   // max packet size
                                            8'h00,
                                            8'h00    // interval
                                            };

   // word form
   logic [0:15][15:0] CFG_DESC_WORDS = '{
                                         16'h0209,
                                         16'h0020,
                                         16'h0101,
                                         16'hC000,
                                         16'h0932,
                                         16'h0004,
                                         16'h0200,
                                         16'h00FF,
                                         16'h0000,
                                         16'h0507,
                                         16'h0201,  // EP1 OUT address
                                         16'h0040,  // max packet size 64 (40h)
                                         16'h0700,
                                         16'h8205,  // EP1 IN address
                                         16'h4002,  // max packet size 64 (40h)
                                         16'h0000
                                         };

   logic [15:0][15:0] CFG_DESC_REV;
   generate
      genvar         j;
      for (j=0; j<16; j++) begin : gen1
         assign CFG_DESC_REV[j] = CFG_DESC_WORDS[j];
      end
   endgenerate

   // imported from package (d13_pkg)
   register_t  register;
   oregister_t register_o;

   // state
   typedef enum int unsigned {RST, IDLE, CHIP_ID_RD, SCRATCH_WR, SCRATCH_RD, HWCFG, HWADDR, MODE, EPCFG, INTRCFG, IREQ_WAIT,
      IREQ_READ, IREQ_DECODE, BUS_RESET, EP0O_STATUS, EP0I_STATUS, EP1O_STATUS, EP1I_STATUS, EP0_FIFO_RD, EP1_FIFO_SZ, EP1_FIFO_RD,
      EP1_FIFO_CLR, EP1_FIFO_WR, EP1_FIFO_VALID, EP1_FIFO_ZLP, SETUP_CLR, SETUP_REQUEST, SETUP_ACK, EP0_STALL, SETUP_RESPONSE,
      SET_ADDR, GET_DEVICE, GET_CONFIG, BUFF_VALID, ZERO_PACKET, SET_CFG, DEBUG0, DEBUG1, DONE, STOP} bus_trans_t;

   bus_trans_t st; // state
   bus_trans_t rt; // return state

   logic [0:63][15:0] wbuff, dcrbuff; // add rbuff (read buffer) for double-buffering

   // registers
   reg         start_meta;
   reg         start;
   reg         write;
   reg         read;
   reg         dword;
   reg         burst;
   reg  [ 5:0] words;
   reg  [ 7:0] addr;
   reg  [31:0] wdata;
   wire [31:0] rdata;
   wire        bus_done;
   reg  [15:0] chip_id;
   reg  [15:0] scratch;
   reg  [31:0] intr;
   reg  [15:0] ep0ostat, ep0istat, ep1ostat, ep1istat;
   reg  [31:0] debug;
   reg  [7:0]  rst_cnt;
   reg  [ 4:0] bcnt;
   reg         int1_meta;
   reg  [ 2:0] int1;
   reg         rst_clr;
   reg         dc_rstf;
   reg         done;
   reg  [1:0]  requestType;
   reg  [7:0]  requestNum;
   reg  [15:0] wValue;
   reg  [15:0] wIndex;
   reg  [15:0] wLength;
   reg         arm;
   reg         lcd;
   reg [63:0][15:0] rbuf; // read buffer


   dc_bus_if dc_u_bus_if(
                        // System Interface
                        .I_CLK        ( I_CLK      ), // Clock 50 MHz
                        .I_RSTF       ( I_RSTF     ), // Reset (active low)
                        // Bus Interface
                        .O_DC_ADDR    ( O_DC_ADDR  ), // Address Bus, [1] = PIO bus of HC(=0) or DC(=1), [0] = command(=1) or data(=0) port
                        .O_DC_CSF     ( O_DC_CSF   ), // Chip Select
                        .O_DC_RDF     ( O_DC_RDF   ), // Read Strobe
                        .O_DC_WRF     ( O_DC_WRF   ), // Write Strobe
                        .IO_DC_DATA   ( IO_DC_DATA ), // Data Bus (bidir)
                        .I_DC_INT1    ( I_DC_INT1  ), // Interrupt 1, from Device Controller
                        // Bus Interface Control
                        .I_START      ( start  ), // Start transfer on Bus Interface
                        .I_WRITE      ( write      ), // Write data on Bus Interface
                        .I_READ       ( read       ), // Read data on Bus Interface
                        .I_DWORD      ( dword      ), // Read double word from device
                        .I_BURST      ( burst      ), // Burst transfer enable
                        .I_WORDS      ( words      ), // Burst transfer number of words (max 64 bytes)
                        .I_ADDR       ( addr       ), // Address to write to Bus Interface
                        .I_WDATA      ( wdata      ), // Data to write to Bus Interface
                        .O_RDATA      ( rdata      ), // Data read from Bus Interface
                        .I_WBUFF      ( wbuff      ), // Data to write to Bus Interface
                        .O_RBUFF      ( dcrbuff    ), // Data read from Bus Interface
                        .I_REGISTER   ( register   ), // register
                        .O_REGISTER   ( register_o ), // register data
                        .O_DONE       ( bus_done   )  // Done with current task
                        );


   // power-on reset delay
   always @(posedge I_CLK or negedge I_RSTF)
     if (~I_RSTF) begin
        rst_cnt <= 0;
     end
     else begin
        if (rst_clr)
           rst_cnt <= 0;
        else if (~rst_cnt[7])
          rst_cnt  <= rst_cnt + 1; // power-on reset ~1.28us (> 800ns)
     end

   // detect rising edge of interrupt signal
   always @(posedge I_CLK or negedge I_RSTF)
     if (~I_RSTF) begin
        int1_meta <= 0;
        int1      <= 0;
     end
     else begin
        int1_meta <= I_DC_INT1;
        int1      <= {int1[1:0], int1_meta};
     end

   // read DcChipID then write and read DcScratch register
   always @(posedge I_CLK or negedge I_RSTF)
     if (~I_RSTF) begin
        st          <= RST;
        start       <= 0;
        write       <= 0;
        read        <= 0;
        dword       <= 0;
        burst       <= 0;
        words       <= 0;
        addr        <= 0;
        wdata       <= 0;
        chip_id     <= 0;
        scratch     <= 0;
        intr        <= 0;
        debug       <= 0;
        dc_rstf     <= 0;
        rst_clr     <= 0;
        bcnt        <= 0;
        wbuff       <= 0;
        ep0ostat    <= 0;
        ep0istat    <= 0;
        ep1ostat    <= 0;
        ep1istat    <= 0;
        requestType <= 0;
        requestNum  <= 0;
        wValue      <= 0;
        wIndex      <= 0;
        wLength     <= 0;
        lcd         <= 0;
        rbuf        <= 0;
        register    <= 0;
        done        <= 0;
     end
     else begin

        start       <= 0;
        write       <= 0;
        read        <= 0;
        dword       <= 0;
        burst       <= 0;
        dc_rstf     <= 1;
        rst_clr     <= 0;
        lcd         <= 0;
        done        <= 0;

        case (st)
          /*
           Hardware Reset sub-routine
          */
          RST: begin
             dc_rstf <= rst_cnt[6] | rst_cnt[7];  // drive RESET_F low then high, this is REQUIRED to drive internal POR of device.
             if (rst_cnt[7]) begin                // reset 800ns.  Able to read chip id after 800ns.
                st <= IDLE;
             end
          end
          IDLE: begin
             st  <= CHIP_ID_RD;
          end
          CHIP_ID_RD: begin
             register     <= '{DC_RCHIP_ID, 0, 1};
             chip_id      <= register_o.data[0];
             DEV_DESC[5]  <= register_o.data[0]; // add chip id to device descriptor
             read         <= 1;
             start        <= 1;
             if (bus_done) begin
                start     <= 0;;
                st        <= SCRATCH_WR;
             end
          end
          SCRATCH_WR: begin
             register  <= '{DC_WSCRATCH_REG, 16'h55AA, 1};
             write     <= 1;
             start     <= 1;
             if (bus_done) begin
                start  <= 0;
                st     <= SCRATCH_RD;
             end
          end
          SCRATCH_RD: begin
             register  <= '{DC_RSCRATCH_REG, 0, 1};
             scratch   <= register_o.data[0];
             read      <= 1;
             start     <= 1;
             if (bus_done) begin
                start  <= 0;
                st     <= MODE;
             end
          end
          /*
           Bus Reset sub-routine
          */
          BUS_RESET: begin
             register <= '{DC_DEV_UNLOCK, 16'hAA37, 1}; // unlock device as mentioned in datasheet
             write    <= 1;
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                st    <= HWADDR;
             end
          end
          /*
           Device HW Configuration sub-routine
          */
          HWADDR: begin // bus reset
             register <= '{DC_WDEV_ADDR, 16'h0080, 1};   // Set Address = 0 upon Bus Reset, Bit[7] is device enable.. IMPORTANT!
             write    <= 1;
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                st    <= MODE;
             end
          end
          MODE: begin
             register  <= '{DC_WMODE, 16'h0009, 1};      // Set Mode, Bit[3] = Interrupt Enable, Bit[0] = Soft Connect
             write     <= 1;
             start     <= 1;
             if (bus_done) begin
                start  <= 0;
                st     <= HWCFG;
             end
          end
          HWCFG: begin
             register  <= '{DC_WHW_CONFIG, 16'h2000, 1}; // HW Configuration, Bit[13] = Disable Lazy Clock
             write     <= 1;
             start     <= 1;
             if (bus_done) begin
                start  <= 0;
                st     <= EPCFG;
             end
          end
          EPCFG: begin
             register  <= '{EPCFG_ADDR[bcnt], EPCFG_DATA[bcnt], 1}; // configure device endpoints and interrupts
             write     <= 1;
             start     <= 1;
             if (bus_done && bcnt == EPCFG_TC-1) begin // program all 16 configuration registers
                bcnt   <= 0;
                start  <= 0;
                st     <= INTRCFG;
             end
             else if (bus_done) begin
                start  <= 0;
                bcnt   <= bcnt + 1;
             end
          end
          INTRCFG: begin
             register  <= '{DC_WIRQ_EN, 32'h0000_0F01, 2}; // Set Interrupts, Bit[11:8] = EP1IN, EP1OUT, EP0IN, EP0OUT, Bit[0] = RESET
             write     <= 1;
             start     <= 1;
             if (bus_done) begin
                start  <= 0;
                st     <= IREQ_WAIT;
             end
          end
          /*
           Interrupt sub-routine
          */
          IREQ_WAIT: begin
             if (~int1[2]) begin             // level triggered (low) via HWCFG.  synchronized to I_CLK (50 MHz)
                st    <= IREQ_READ;
             end
          end
          IREQ_READ: begin                   // read the interrupt source register (0xC0)
             register <= '{DC_RIRQ_REG, 0, 2};
             intr     <= register_o.data[1:0];
             read     <= 1;
             start    <= 1;
             if (bus_done) begin  // should go reset -> suspend -> control IN -> control OUT, then loop back to IREQ_READ before going to IREQ_WAIT
                start <= 0;
                st    <= IREQ_DECODE;
             end
          end
          IREQ_DECODE: begin
             if (intr[0] == 1) begin           // Bus Reset condition
                st     <= BUS_RESET;
             end
             //if (intr[1] == 1) begin           // Suspend condition (enable in HW!!!!)
             //   st     <= SUSPEND;
             //end
             else if (intr[9] == 1) begin      // EP0IN (Control IN Endpoint) RESEND?? MALFORMED PACKET?
                st     <= EP0I_STATUS;         // read status register to clear interrupt
             end
             else if (intr[8] == 1) begin      // EP0OUT (Control OUT Endpoint) SETUP? or DATA? need to define
                st     <= EP0O_STATUS;         // read status register to clear interrupt
             end
             else if (intr[11] == 1) begin     // EP1IN (Bulk IN Endpoint)
                st     <= EP1I_STATUS;         // read status register to clear interrupt
             end
             else if (intr[10] == 1) begin     // EP1OUT (Bulk OUT Endpoint)
                st     <= EP1O_STATUS;         // read status register to clear interrupt
             end
             else begin                        // uknown, should not reach this state per device configuration
                st     <= IREQ_WAIT;           // go back to interrupt wait state
             end
          end

          /*
           EP0 (Control) IN Status sub-routine
          */
          EP0I_STATUS: begin                         // reading EP status register clears the interrupt bit
             register <= '{DC_REP0IN_STATUS, 0, 1};
             ep0istat <= register_o.data[0];
             read     <= 1;
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                if (ep0istat[5] == 1) begin          // buffer is full
                   st    <= STOP;                    // revisit this since there's data in the buffer, resend or empty packet?
                end
                else if (ep0istat[5] == 0) begin     // buffer is empty
                   st    <= ZERO_PACKET;
                end
                else begin
                   st    <= DONE;                    // wait for another interrupt
                end
             end
          end
          /*
           EP0 (Control) OUT Status sub-routine
          */
          EP0O_STATUS: begin                            // reading EP status register clears the interrupt bit
             register <= '{DC_REP0OUT_STATUS, 0, 1};
             ep0ostat <= register_o.data[0];
             read     <= 1;
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                if (ep0ostat[5] == 0) begin             // wrong status, primary buffer is not full
                   st        <= STOP;
                end
                else if (ep0ostat[3:2] == 2'b01) begin  // setup packet and not overwrite
                   register  <= '{DC_REP0OUT_BUFF, 0, SETUP_FIFO_WORDS}; // setup request (8 bytes) + packet length (2 bytes)
                   st        <= EP0_FIFO_RD;            // process setup packet
                   rt        <= SETUP_REQUEST;
                end
                else if (ep0ostat[5] == 1) begin        // buffer full, usually handshake (i.e. empty packet after device descriptor), ACK'd when EP0 status was read.
                   register  <= '{DC_REP0OUT_BUFF, 0, 1};
                   st        <= EP0_FIFO_RD;            // process empty packet
                   rt        <= EP0_STALL;
                end
                else begin
                   st <= DONE;                          // wait for another interrupt
                end
             end
          end
          /*
           EP1 (Bulk) IN Status sub-routine
          */
          EP1I_STATUS: begin                         // reading EP status register clears the interrupt bit
             register <= '{DC_REP1IN_STATUS, 0, 1};
             ep1istat <= register_o.data[0];
             read     <= 1;
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                if (ep1istat[5] == 1) begin          // buffer is full
                   st    <= DONE;                    // fix for libusb?  Wrong status, resume execution per programmers manual.
                end
                else if (ep1istat[5] == 0) begin     // buffer is empty
                   st    <= DONE;
                end
                else begin
                   debug <= 32'hDEADDEAD;
                   st    <= STOP;
                end
             end
          end
          /*
           EP1 (Bulk) OUT Status sub-routine
          */
          EP1O_STATUS: begin                         // reading EP status register clears the interrupt bit
             register <= '{DC_REP1OUT_STATUS, 0, 1};
             ep1ostat <= register_o.data[0];
             read     <= 1;
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                if (ep1ostat[5] == 0) begin          // wrong status, primary buffer is not full
                   debug <= {16'hDEAD, ep0ostat};
                   st    <= STOP;
                end
                else if (ep1ostat[5] == 1) begin     // buffer is full
                   st    <= EP1_FIFO_SZ;
                end
                else begin
                   debug <= 32'hDEADDEAD;
                   st    <= STOP;
                end
             end
          end

          /*
           Read EP1 (Control) Buffer
          */
          EP0_FIFO_RD: begin
             read     <= 1;
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                if (register_o.data[0] == 0) begin // handshake (emtpy packet)
                   //lcd   <= 1;
                   //debug <= {intr[15:0], ep0ostat};
                   st <= rt;
                end
                else begin
                   st <= rt;
                end
             end
          end

          /*
           Read EP1 (Bulk) Buffer Packet Size
          */
          EP1_FIFO_SZ: begin
             register  <= '{DC_REP1OUT_BUFF, 0, 1};
             read      <= 1;
             start     <= 1;
             if (bus_done) begin
                start  <= 0;
                words  <= (register_o.data[0][0]) ? register_o.data[0][6:1]+2'b10 : register_o.data[0][6:1]+1'b1;
                st     <= EP1_FIFO_RD;
             end
          end
          /*
           Read EP1 (Bulk) OUT Buffer. Should double-buffer. Host tries to send next 64 bytes while this is reading.  Host sees 'NAK' and polls.
          */
          EP1_FIFO_RD: begin
             register <= '{DC_REP1OUT_BUFF, 0, words}; // bulk size + packet length
             read     <= 1;
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                st    <= EP1_FIFO_CLR;
             end
          end
          /*
           Clear EP1 (Bulk) OUT Buffer
          */
          EP1_FIFO_CLR: begin
             register <= '{DC_CEP1OUT_BUFF, 0, 0};
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                st    <= EP1_FIFO_WR;
             end
          end
          /*
           Write EP1 (Bulk) IN Buffer
          */
          EP1_FIFO_WR: begin
             register  <= '{DC_WEP1IN_BUFF, register_o.data, words}; // loopback buffer size + packet data.
             write     <= 1;
             start     <= 1;
             if (bus_done) begin
                start  <= 0;
                lcd    <= 1;
                debug  <= {register_o.data[1], {10'b0, words}};
                st     <= EP1_FIFO_VALID;
             end
          end
          /*
           Write EP1 (Bulk) IN Buffer an Zero Length Packet (unused)
          */
          EP1_FIFO_ZLP: begin
             register <= '{DC_WEP1IN_BUFF, 0, 1};  // write packet length of zero to fifo
             write    <= 1;
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                st    <= EP1_FIFO_VALID;
             end
          end
          /*
           Validate EP1 (Bulk) IN Buffer
          */
          EP1_FIFO_VALID: begin
             register <= '{DC_VEP1IN_BUFF, 0, 0};
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                st    <= DONE;
             end
          end

          /*
           Setup Request Packet sub-routine
          */
          SETUP_REQUEST: begin   // TODO: clean this up.  Doesn't look right
             requestType  <= register_o.data[1][6:5];
             requestNum   <= register_o.data[1][15:8];
             wValue       <= register_o.data[2];
             wIndex       <= register_o.data[3];
             wLength      <= register_o.data[4];
             if (register_o.data[0] == SETUP_SIZE_BYTES) begin  // compare the length in bytes inside the OUT buffer
                st <= SETUP_ACK;
             end
             else begin
                st <= DONE;
             end
          end
          SETUP_ACK: begin                         // arrival of setup packet flushes the IN buffer and disables
             register <= '{DC_ACK_SETUP, 0, 0};    // validate and clear buffer commands for Control IN/OUT EP's
                                                   // the user must re-enable these commands by sending an acknowledge
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                st    <= SETUP_CLR;                // setup command to BOTH the control endpoints to explicity ackowledge
             end                                   // the setup packet
          end
          SETUP_CLR: begin
             register <= '{DC_CEP0OUT_BUFF, 0 , 0}; // reception of complete packet causes buffer full flag of an OUT endpoint
                                                    // to be set... read rest 70h, this is illegal??
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                st    <= SETUP_RESPONSE;
             end
          end

          /*
           Setup Response Packet sub-routine
          */
          SETUP_RESPONSE: begin
             if (requestType == 0) begin      // standard request
                case (requestNum)
                  8'd5: st    <= SET_ADDR;
                  8'd6: begin                 // get descriptor
                     case (wValue[15:8])
                       8'd1: st    <= GET_DEVICE;
                       8'd2: st    <= GET_CONFIG;
                       8'd6: st    <= EP0_STALL;    // get device qualifier. Note: stall is default below
                       8'd9: st    <= ZERO_PACKET;
                       default: st <= EP0_STALL;
                     endcase
                  end
                  8'd9: begin
                     st <= SET_CFG;
                  end
                  default: begin
                     st <= EP0_STALL;
                  end
                endcase
             end
             else begin
                // Not Implemented, class request (requestType == 1) and vendor request (requestType == 2)
                st <= EP0_STALL;
             end
          end
          GET_DEVICE: begin // Get Device Descriptor
             register           <= '{DC_WEP0IN_BUFF, 0, DEV_DESC_FIFO_WORDS};
             register.data[0]   <= DEV_DESC_SIZE_BYTES;
             register.data[9:1] <= DEV_DESC_REV;
             write              <= 1;
             start              <= 1;
             if (bus_done) begin
                start           <= 0;
                st              <= BUFF_VALID;
             end
          end
          GET_CONFIG: begin // Get Configuration Descriptor
             register            <= '{DC_WEP0IN_BUFF, 0, wLength};
             register.data[0]    <= wLength;
             register.data[16:1] <= CFG_DESC_REV;
             register.words      <= (wLength[0]) ? wLength[15:1]+2 : wLength[15:1]+1;
             write               <= 1;
             start               <= 1;
             if (bus_done) begin
                start            <= 0;
                st               <= BUFF_VALID;
             end
          end
          SET_ADDR: begin // Set Address
             register <= '{DC_WDEV_ADDR, {17'b1, wValue[6:0]}, 1};
             write    <= 1;
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                st    <= ZERO_PACKET;
             end
          end
          SET_CFG: begin  // Set Configuration
                          // Done!! Send zero length. The user determines the configuration value from the Setup Packet.
                          // If the value is zero, the user must clear the configuration flag in its memory and disable the endpoint
                          // If the value is one, the user must set the configuration flag.  Once set, the user must send the zero-data packet
                          // at the acknowledgement phase.
             st    <= ZERO_PACKET;
          end
          ZERO_PACKET: begin
             register <= '{DC_WEP0IN_BUFF, 0, 1};  // write packet length of zero to fifo
             write    <= 1;
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                st    <= BUFF_VALID;
             end
          end
          BUFF_VALID: begin
             register <= '{DC_VEP0IN_BUFF, 0, 0};
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                lcd   <= 1;
                debug <= {requestNum, wValue};
                st    <= DONE;
             end
          end
          EP0_STALL: begin
             register <= '{DC_SEP0OUT_STALL, 0 , 0};   // not sure if EP0OUT or EP0IN, out is illegal, stall takes a lot of time malformed packet.
             start    <= 1;
             if (bus_done) begin
                start <= 0;
                st    <= DONE;
             end
          end

          /*
           Debug sub-routine
          */
          //DEBUG0: begin
          //   register <= '{DC_WEP0IN_BUFF, 0, 1};  // write packet length of zero to fifo
          //   write    <= 1;
          //   if (bus_done) begin
          //      start <= 1;
          //      st    <= DEBUG1;
          //   end
          //end
          //DEBUG1: begin
          //   register <= '{DC_VEP0IN_BUFF, 0, 0};  // validate fifo
          //   if (bus_done) begin
          //      debug <= {requestNum, wValue};
          //      arm   <= 1;
          //      st    <= DONE;
          //   end
          //end

          DONE: begin
             done <= 1;
             st   <= IREQ_WAIT;
          end

          STOP: begin
             done <= 1;
          end
        endcase
     end

   assign O_CHIP_ID  = chip_id;
   assign O_SCRATCH  = scratch;
   assign O_INTR     = intr;
   assign O_DEBUG    = debug;
   assign O_RDATA    = {scratch, chip_id};
   assign O_DATA_RDY = lcd;
   assign O_DONE     = done;
   assign O_DC_RSTF  = dc_rstf;

endmodule // dc_if
