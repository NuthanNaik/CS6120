build_lib_example(
  NAME main-propagation-loss
  SOURCE_FILES main-propagation-loss.cc
  LIBRARIES_TO_LINK
    ${libcore}
    ${libpropagation}
    ${libconfig-store}
    ${libstats}
    ${libmobility}
    ${libbuildings}
)

build_lib_example(
  NAME ques1.1.1
  SOURCE_FILES ques1.1.1.cc
  LIBRARIES_TO_LINK
    ${libcore}
    ${libpropagation}
    ${libconfig-store}
    ${libstats}
    ${libmobility}
    ${libbuildings}
)

build_lib_example(
  NAME ques1.1.2
  SOURCE_FILES ques1.1.2.cc
  LIBRARIES_TO_LINK
    ${libcore}
    ${libpropagation}
    ${libconfig-store}
    ${libstats}
    ${libmobility}
    ${libbuildings}
)

build_lib_example(
  NAME ques1.2.1
  SOURCE_FILES ques1.2.1.cc
  LIBRARIES_TO_LINK
    ${libcore}
    ${libpropagation}
    ${libconfig-store}
    ${libstats}
    ${libmobility}
    ${libbuildings}
    ${libantenna}
)

build_lib_example(
  NAME ques1.2.2
  SOURCE_FILES ques1.2.2.cc
  LIBRARIES_TO_LINK
    ${libcore}
    ${libpropagation}
    ${libconfig-store}
    ${libstats}
    ${libmobility}
    ${libbuildings}
    ${libantenna}
)

build_lib_example(
  NAME ques2.1.1
  SOURCE_FILES ques2.1.1.cc
  LIBRARIES_TO_LINK
    ${libcore}
    ${libpropagation}
    ${libconfig-store}
    ${libstats}
    ${libmobility}
    ${libbuildings}
)

build_lib_example(
  NAME ques2.1.2
  SOURCE_FILES ques2.1.2.cc
  LIBRARIES_TO_LINK
    ${libcore}
    ${libpropagation}
    ${libconfig-store}
    ${libstats}
    ${libmobility}
    ${libbuildings}
)

build_lib_example(
  NAME ques2.2.1
  SOURCE_FILES ques2.2.1.cc
  LIBRARIES_TO_LINK
    ${libcore}
    ${libpropagation}
    ${libconfig-store}
    ${libstats}
    ${libmobility}
    ${libbuildings}
    ${libantenna}
)

build_lib_example(
  NAME ques2.2.2
  SOURCE_FILES ques2.2.2.cc
  LIBRARIES_TO_LINK
    ${libcore}
    ${libpropagation}
    ${libconfig-store}
    ${libstats}
    ${libmobility}
    ${libbuildings}
    ${libantenna}
)


build_lib_example(
  NAME jakes-propagation-model-example
  SOURCE_FILES jakes-propagation-model-example.cc
  LIBRARIES_TO_LINK
    ${libcore}
    ${libpropagation}
    ${libbuildings}
)
