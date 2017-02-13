package main

import (
	"errors"
	"net/http"
	"strings"

	"fmt"

	bimg "gopkg.in/h2non/bimg.v1"
	filetype "gopkg.in/h2non/filetype.v0"
)

// Image stores an image binary buffer and its MIME type
type Image struct {
	Body []byte
	Mime string
}

func Process(buf []byte, opts bimg.Options) (out Image, err error) {
	defer func() {
		if r := recover(); r != nil {
			switch value := r.(type) {
			case error:
				err = value
			case string:
				err = errors.New(value)
			default:
				err = errors.New("libvips internal error")
			}
			out = Image{}
		}
	}()

	buf, err = bimg.Resize(buf, opts)
	if err != nil {
		return Image{}, err
	}

	mime := GetImageMimeType(bimg.DetermineImageType(buf))

	return Image{Body: buf, Mime: mime}, nil
}

func ProcessImage(resource *Resource, options *ImageOptions) error {

	// Read file
	buf, err := resource.Read()
	if err != nil {
		return err
	}

	// Infer the body MIME type via mimesniff algorithm
	mimeType := http.DetectContentType(buf)

	// If cannot infer the type, infer it via magic numbers
	if mimeType == "application/octet-stream" {
		kind, err := filetype.Get(buf)
		if err == nil && kind.MIME.Value != "" {
			mimeType = kind.MIME.Value
		}
	}

	// Infer text/plain responses as potential SVG image
	if strings.Contains(mimeType, "text/plain") && len(buf) > 8 && bimg.IsSVGImage(buf) {
		mimeType = "image/svg+xml"
	}

	// Finally check if image MIME type is supported
	if IsImageMimeTypeSupported(mimeType) == false {
		return fmt.Errorf("MimeType %s is not supported", mimeType)
	}

	img, err := Process(buf, BimgOptions(options))
	if err != nil {
		return err
	}

	resource.MimeType = img.Mime
	resource.Body = img.Body

	return nil
}

// GetImageMimeType returns the MIME type based on the given image type code.
func GetImageMimeType(code bimg.ImageType) string {
	switch code {
	case bimg.PNG:
		return "image/png"
	case bimg.WEBP:
		return "image/webp"
	case bimg.TIFF:
		return "image/tiff"
	case bimg.GIF:
		return "image/gif"
	case bimg.SVG:
		return "image/svg+xml"
	case bimg.PDF:
		return "application/pdf"
	default:
		return "image/jpeg"
	}
}
