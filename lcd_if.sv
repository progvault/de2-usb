module lcd_if (
                   // System Interface
                   input        I_CLK,
                   input        I_RSTF,
                   output       O_LCD_ON,
                   // LCD Bus Interface
                   output       O_LCD_EN,
                   output       O_LCD_RS,    // Register select, 0 = Command, 1 = Data
                   output       O_LCD_RWF,   // Read Write select, 0 = Write, 1 = Read
                   output [7:0] O_LCD_DATA,
                   // LCD Control Interface
                   input        I_START,
                   input [31:0] I_REG_DATA,  // DC Register Data
                   output       O_DONE
                   );

   //                                        111111
   //                              0123456789012345
   logic [0:15][7:0] lcd_line1  = "Register Data   ";
   logic [0:15][7:0] lcd_line2;
   //logic [0:15][7:0] lcd_line2  = "string2         ";

   typedef enum {IDLE, WR_ID0, WR_ID1, DONE} bus_trans_t;
   bus_trans_t st; // state


   wire lcd_done;
   reg  lcd_start;
   reg  done;
   reg  [31:0] hex0, hex1;     // ascii hex


   bin2ascii u0_bin2ascii (
                           // System Interface
                           .I_CLK  ( I_CLK      ),
                           .I_RSTF ( I_RSTF     ),
                           // Binary to Hexadecimal
                           .I_BIN  ( I_REG_DATA[15:0] ),
                           .O_HEX  ( hex0       )
                          );

   bin2ascii u1_bin2ascii (
                           // System Interface
                           .I_CLK  ( I_CLK      ),
                           .I_RSTF ( I_RSTF     ),
                           // Binary to Hexadecimal
                           .I_BIN  ( I_REG_DATA[31:16] ),
                           .O_HEX  ( hex1       )
                          );

   lcd_bus_if u_lcd_bus_if(
                           // System Interface
                           .I_CLK      ( I_CLK      ),
                           .I_RSTF     ( I_RSTF     ),
                           .O_LCD_ON   ( O_LCD_ON   ),
                           // LCD Bus Interface
                           .O_LCD_EN   ( O_LCD_EN   ),
                           .O_LCD_RS   ( O_LCD_RS   ), // Register select, 0 = Command, 1 = Data
                           .O_LCD_RWF  ( O_LCD_RWF  ), // Read Write select, 0 = Write, 1 = Read
                           .O_LCD_DATA ( O_LCD_DATA ),
                           // LCD Interface Control
                           .I_START    ( lcd_start  ),
                           .I_WDATA0   ( lcd_line1  ),
                           .I_WDATA1   ( lcd_line2  ),
                           .O_DONE     ( lcd_done   )
                           );

   always @(posedge I_CLK or negedge I_RSTF)
     if (~I_RSTF) begin
        st        <= IDLE;
        lcd_start <= 0;
        done      <= 0;
        lcd_line2 <= '{16{8'h20}}; // 16 values of 0x20 (space)
     end
     else begin

        // defaults
        lcd_start <= 0;
        done      <= 0;

        case(st)
          IDLE: begin
             if (I_START)
               st <= WR_ID0;
          end
          WR_ID0: begin
             lcd_line2[7] <= hex0[7:0];
             lcd_line2[6] <= hex0[15:8];
             lcd_line2[5] <= hex0[23:16];
             lcd_line2[4] <= hex0[31:24];
             lcd_line2[3] <= hex1[7:0];
             lcd_line2[2] <= hex1[15:8];
             lcd_line2[1] <= hex1[23:16];
             lcd_line2[0] <= hex1[31:24];
             st <= WR_ID1;
          end
          WR_ID1: begin
             lcd_start <= 1;
             st        <= DONE;
          end
          DONE: begin
             done <= 1;
             st   <= IDLE;
          end
        endcase
     end

   assign O_DONE = done;

endmodule // lcd_if
