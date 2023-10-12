package network

import (
	"os"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var EncoderConfig = zapcore.EncoderConfig{
	TimeKey:          "time",
	MessageKey:       "msg",
	LevelKey:         "level",
	EncodeLevel:      zapcore.CapitalLevelEncoder,
	EncodeTime:       zapcore.TimeEncoderOfLayout("2006-01-02 15:04:05.000"),
	CallerKey:        "file",
	EncodeCaller:     zapcore.ShortCallerEncoder,
	ConsoleSeparator: " ",
}
var AtomicLevel = zap.NewAtomicLevel()
var Core = zapcore.NewCore(zapcore.NewConsoleEncoder(EncoderConfig), os.Stdout, AtomicLevel)
var SugaredLogger = zap.New(Core, zap.AddCaller()).Sugar()

var Fatalf = SugaredLogger.Fatalf
var Errorf = SugaredLogger.Errorf
var Panicf = SugaredLogger.Panicf
var Warnf = SugaredLogger.Warnf
var Infof = SugaredLogger.Infof
var Debugf = SugaredLogger.Debugf
var SetLevel = AtomicLevel.SetLevel
