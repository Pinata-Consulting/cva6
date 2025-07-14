// Copyright (c) 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author: Wolfgang Roenninger <wroennin@ethz.ch>

// Description: Functional module of a generic SRAM
//
// Parameters:
// - NumWords:    Number of words in the macro. Address width can be calculated with:
//                `AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1`
//                The module issues a warning if there is a request on an address which is
//                not in range.
// - DataWidth:   Width of the ports `wdata_i` and `rdata_o`.
// - ByteWidth:   Width of a byte, the byte enable signal `be_i` can be calculated with the
//                ceiling division `ceil(DataWidth, ByteWidth)`.
// - NumPorts:    Number of read and write ports. Each is a full port. Ports with a higher
//                index read and write after the ones with lower indices.
// - Latency:     Read latency, the read data is available this many cycles after a request.
// - SimInit:     Macro simulation initialization. Values are:
//                "zeros":  Each bit gets initialized with 1'b0.
//                "ones":   Each bit gets initialized with 1'b1.
//                "random": Each bit gets random initialized with 1'b0 or 1'b1.
//                "none":   Each bit gets initialized with 1'bx. (default)
// - PrintSimCfg: Prints at the beginning of the simulation a `Hello` message with
//                the instantiated parameters and signal widths.
// - ImplKey:     Key by which an instance can refer to a specific implementation (e.g. macro).
//                May be used to look up additional parameters for implementation (e.g. generator,
//                line width, muxing) in an external reference, such as a configuration file.
//
// Ports:
// - `clk_i`:   Clock
// - `rst_ni`:  Asynchronous reset, active low
// - `req_i`:   Request, active high
// - `we_i`:    Write request, active high
// - `addr_i`:  Request address
// - `wdata_i`: Write data, has to be valid on request
// - `be_i`:    Byte enable, active high
// - `rdata_o`: Read data, valid `Latency` cycles after a request with `we_i` low.
//
// Behaviour:
// - Address collision:  When Ports are making a write access onto the same address,
//                       the write operation will start at the port with the lowest address
//                       index, each port will overwrite the changes made by the previous ports
//                       according how the respective `be_i` signal is set.
// - Read data on write: This implementation will not produce a read data output on the signal
//                       `rdata_o` when `req_i` and `we_i` are asserted. The output data is stable
//                       on write requests.

module tc_sram #(
  parameter int unsigned NumWords     = 1024,
  parameter int unsigned DataWidth    = 128,
  parameter int unsigned ByteWidth    = 8,
  parameter int unsigned NumPorts     = 2,
  parameter int unsigned Latency      = 1
) (
  input  logic                 clk_i,
  input  logic                 rst_ni,
  input  logic  [NumPorts-1:0] req_i,
  input  logic  [NumPorts-1:0] we_i,
  input  logic  [$clog2(NumWords)-1:0] addr_i [NumPorts],
  input  logic  [DataWidth-1:0] wdata_i [NumPorts],
  input  logic  [(DataWidth/ByteWidth)-1:0] be_i [NumPorts],
  output logic  [DataWidth-1:0] rdata_o [NumPorts]
);

  logic [DataWidth-1:0] mem [0:NumWords-1];

  // Synchronous write, asynchronous read
  always_ff @(posedge clk_i) begin
    for (int i = 0; i < NumPorts; i++) begin
      if (req_i[i] && we_i[i]) begin
        for (int j = 0; j < DataWidth/ByteWidth; j++) begin
          if (be_i[i][j])
            mem[addr_i[i]][j*ByteWidth +: ByteWidth] <= wdata_i[i][j*ByteWidth +: ByteWidth];
        end
      end
    end
  end

  genvar i;
  generate
    for (i = 0; i < NumPorts; i++) begin : port
      assign rdata_o[i] = mem[addr_i[i]];
    end
  endgenerate

endmodule
