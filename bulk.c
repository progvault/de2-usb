#include <stdlib.h>
#include <stdio.h>

#include <libusb-1.0/libusb.h>

/* Change VENDOR_ID and PRODUCT_ID depending on device */
#define VENDOR_ID   0x0471
#define PRODUCT_ID  0x3630

/* Define number of bytes to transfer */
#define BYTES 1024*768*3 // bytes
//#define BYTES 64*64      // bytes
#define EP_SIZE 64       // bytes
#define TIMEOUT 5*1000   // milliseconds

/* Use a global variable to keep the device handle */
static struct libusb_device_handle *devh = NULL;

/* The Endpoint addresses are hard-coded.  You should use libusb -v to find
 * the values corresponding to device
 */
static int ep_in_addr  = 0x82;
static int ep_out_addr = 0x01;

int write_chars(unsigned char * data, int length)
{
  /* To send a char to the device simply initiate a bulk_transfer to the Endpoint
   * with the address ep_out_addr.
   */
  int actual_length;

  int rc = libusb_bulk_transfer(devh, ep_out_addr, data, length, &actual_length, TIMEOUT);

  if (rc < 0)
  {
    fprintf(stderr, "Error while sending char: %d\n", rc);
    return -1;
  }

  return actual_length;
}

int read_chars(unsigned char * data, int length)
{
  /* To receive characters from the device initiate a bulk_transfer to the Entpoint
   * with address ep_in_addr
   */
  int actual_length;

  int rc = libusb_bulk_transfer(devh, ep_in_addr, data, length, &actual_length, TIMEOUT);

  if (rc == LIBUSB_ERROR_TIMEOUT)
  {
    printf("timeout (%d)\n", actual_length);
    return -1;
  }
  else if (rc < 0)
  {
    fprintf(stderr, "Error while waiting for char: %d\n", rc);
    return -1;
  }

  return actual_length;
}

int main(int argc, char **argv)
{
  int rc;

  /* Initialize libusb */
  rc = libusb_init(NULL);

  if (rc < 0)
  {
    fprintf(stderr, "Error Initializing libusb: %s\n", libusb_error_name(rc));
    exit(1);
  }

  /* Set debugging output to max level */
  libusb_set_debug(NULL, 3);

  /* Look for a specific device and open it */
  devh = libusb_open_device_with_vid_pid(NULL, VENDOR_ID, PRODUCT_ID);
  if (!devh)
  {
    fprintf(stderr, "Error finding USB device\n");
    goto out;
  }

  /* We can now start sending or receiving data to the device */
  unsigned char buf[BYTES];
  unsigned char rbuf[EP_SIZE];
  int len;
  int j;
  int i;
  int n;
  int l;
  int res;

  // fill buffer
  for (n = 0; n < BYTES; n++)
  {
    buf[n] = 0x00+n;
  }

  // loopback data, write-read back-to-back (~431 kB/sec), should be able to add twice the speed by interleaving
  for (l = 0; l < BYTES/EP_SIZE; l++)
  {
    len = write_chars(buf+l*EP_SIZE, EP_SIZE);
    len = read_chars(rbuf, EP_SIZE);
    res = memcmp(rbuf, buf+l*EP_SIZE, sizeof(rbuf));
    if (res != 0)
      fprintf(stderr, "Miscompare: block %d\n", l);
  }

  libusb_release_interface(devh, 0);

out:
  if (devh)
  {
    libusb_close(devh);
  }
  libusb_exit(NULL);

  return rc;
}
