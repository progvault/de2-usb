module usb (
        // System Interface
        input         I_CLK,             // Clock 50 MHz
        input         I_RSTF,            // Reset (active low)
        input         I_START,           // Start Test (active low)
        output [15:0] O_CHIP_ID,         // Chip ID
        output [15:0] O_SCRATCH,         // Scratch content
        output        O_BLINKY,          // Blinky LED
        output        O_INT1_LED,        // Interrupt 1 LED
        output        O_LCD_ON,          // LCD On
        output        O_LCD_EN,          // LCD Enable
        output        O_LCD_RS,          // LCD Register select, 0 = Command, 1 = Data
        output        O_LCD_RWF,         // LCD Read Write select, 0 = Write, 1 = Read
        output [ 7:0] O_LCD_DATA,        // LCD Data
        output [ 6:0] O_HEX0,            // Seven Segment 0
        output [ 6:0] O_HEX1,            // Seven Segment 1
        output [ 6:0] O_HEX2,            // Seven Segment 2
        output [ 6:0] O_HEX3,            // Seven Segment 3
        output [ 6:0] O_HEX4,            // Seven Segment 4
        output [ 6:0] O_HEX5,            // Seven Segment 5
        output [ 6:0] O_HEX6,            // Seven Segment 6
        output [ 6:0] O_HEX7,            // Seven Segment 7
        // Device Controller Interface
        output        O_DC_RSTF,         // Reset the Device Controller (~800ns)
        inout         O_DC_FSPEED,       // Full Speed, 0 = Enable, Z = Disable
        inout         O_DC_LSPEED,       // Low Speed, 0 = Enable, Z = Disable
        output [ 1:0] O_DC_ADDR,         // Address Bus, [1] = PIO bus of HC(=0) or DC(=1), [0] = command(=1) or data(=0) port
        output        O_DC_CSF,          // Chip Select
        output        O_DC_RDF,          // Read Strobe
        output        O_DC_WRF,          // Write Strobe
        inout [15:0]  IO_DC_DATA,        // Data Bus (bidir)
        input         I_DC_INT0,         // Interrupt 0, from Host Controller (unused)
        input         I_DC_INT1,         // Interrupt 1, from Device Controller
        output        O_DC_DACK0F,       // DMA Acknowledge 0 (unused)
        output        O_DC_DACK1F        // DMA Acknowledge 1 (unused)
        );

   logic [64:0][15:0] dc_data;
   wire  [31:0] rdata;
   reg   [24:0] led_cnt;
   reg   [15:0] chip_id;
   reg   [15:0] scratch;
   wire  [15:0] intr;
   wire  [31:0] debug;
   reg          dc_data_rdy;
   reg          dc_done;
   reg          lcd_done;
   reg          dc_int1;

   assign dc_int1 = I_DC_INT1;

   dc_if u_dc_if (
                    // System Interface
                    .I_CLK      ( I_CLK       ),  // Clock 50 MHz
                    .I_RSTF     ( I_RSTF      ),  // Reset (active low)
                    .I_START    ( I_START     ),
                    .O_CHIP_ID  ( chip_id     ),
                    .O_SCRATCH  ( scratch     ),
                    .O_INTR     ( intr        ),
                    .I_DATA_RDY ( dc_data_rdy ),  // Data Ready to USB
                    .I_DATA     ( dc_data     ),  // Bulk Endpoint IN Data (loopback)
                    .O_DATA_RDY ( dc_data_rdy ),  // Data Ready from USB
                    .O_DATA     ( dc_data     ),  // Bulk Endpoint OUT Data
                    .O_RDATA    ( rdata       ),  // Read Data
                    .O_DEBUG    ( debug       ),
                    .O_DONE     ( dc_done     ),  // DC Done
                    // Bus Interface
                    .O_DC_RSTF  ( O_DC_RSTF   ),  // Reset the Device Controller (~800ns)
                    .O_DC_ADDR  ( O_DC_ADDR   ),  // Address Bus, [1] = PIO bus of HC(=0) or DC(=1), [0] = command(=1) or data(=0) port
                    .O_DC_CSF   ( O_DC_CSF    ),  // Chip Select
                    .O_DC_RDF   ( O_DC_RDF    ),  // Read Strobe
                    .O_DC_WRF   ( O_DC_WRF    ),  // Write Strobe
                    .IO_DC_DATA ( IO_DC_DATA  ),  // Data Bus (bidir)
                    .I_DC_INT1  ( dc_int1     )   // Interrupt 1, from Device Controller
                    );

   lcd_if u_lcd_if (
                    // System Interface
                    .I_CLK      ( I_CLK       ),
                    .I_RSTF     ( I_RSTF      ),
                    .O_LCD_ON   ( O_LCD_ON    ),
                    // LCD Bus Interface
                    .O_LCD_EN   ( O_LCD_EN    ),
                    .O_LCD_RS   ( O_LCD_RS    ), // Register select, 0 = Command, 1 = Data
                    .O_LCD_RWF  ( O_LCD_RWF   ), // Read Write select, 0 = Write, 1 = Read
                    .O_LCD_DATA ( O_LCD_DATA  ),
                    .I_START    ( dc_data_rdy ),
                    .I_REG_DATA ( debug       ), // Register Data
                    .O_DONE     ( lcd_done    )
                    );

   sseg u0_sseg(
               .I_CLK  ( I_CLK          ),
               .I_DATA ( chip_id[3:0]   ),
               .O_SSEG ( O_HEX0         )
               );

   sseg u1_sseg(
               .I_CLK  ( I_CLK          ),
               .I_DATA ( chip_id[7:4]   ),
               .O_SSEG ( O_HEX1         )
               );

   sseg u2_sseg(
               .I_CLK  ( I_CLK          ),
               .I_DATA ( chip_id[11:8]  ),
               .O_SSEG ( O_HEX2         )
               );
   sseg u3_sseg(
               .I_CLK  ( I_CLK          ),
               .I_DATA ( chip_id[15:12] ),
               .O_SSEG ( O_HEX3         )
               );

   sseg u4_sseg(
               .I_CLK  ( I_CLK          ),
               .I_DATA ( scratch[3:0]   ),
               .O_SSEG ( O_HEX4         )
               );

   sseg u5_sseg(
               .I_CLK  ( I_CLK          ),
               .I_DATA ( scratch[7:4]   ),
               .O_SSEG ( O_HEX5         )
               );

   sseg u6_sseg(
               .I_CLK  ( I_CLK          ),
               .I_DATA ( scratch[11:8]  ),
               .O_SSEG ( O_HEX6         )
               );
   sseg u7_sseg(
               .I_CLK  ( I_CLK          ),
               .I_DATA ( scratch[15:12] ),
               .O_SSEG ( O_HEX7         )
               );

   // Blinky LED
   always @(posedge I_CLK or negedge I_RSTF)
     if (~I_RSTF) begin
        led_cnt <= 0;
     end
     else begin
        led_cnt <= led_cnt + 1;
     end

   assign O_CHIP_ID    = chip_id;
   assign O_SCRATCH    = scratch;

   assign O_DC_FSPEED  = 1'b0;
   assign O_DC_LSPEED  = 1'bZ;  // revisit - may need to drive H or L during suspend to reduce power
   assign O_DC_DACK0F  = 1'b1;
   assign O_DC_DACK1F  = 1'b1;
   assign O_BLINKY     = led_cnt[24];
   assign O_INT1_LED   = dc_int1;

   // revisit:
   //   Suspend
   //   1. May need to drive H or L during suspend to reduce power
   //   2. May need to disable internal clocks by clearing bit CLKRUN of DcHardwareConfiguration register
   //   3. Set and clear the GOSUSP in the DcMode reigster
   //   Resume
   //   1. Send unlock device command

endmodule // usb
