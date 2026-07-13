cmake_minimum_required(VERSION 3.25.0 FATAL_ERROR)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

#== step 1          要求 CMake 版本至少是 3.25，不满足就报致命错误。
#==.                   整个项目使用 C++17，并强制要求支持这个标准（不能退回到更低标准）



set(PROJECT AmneziaVPN)
set(AMNEZIAVPN_VERSION 4.9.0.3)
#---step 2 --           先把项目名和版本存在变量里，下面 project() 会用到。



set(QT_CREATOR_SKIP_PACKAGE_MANAGER_SETUP ON CACHE BOOL "" FORCE)
#---step 3 ---          告诉 Qt Creator 不要自动跑包管理器设置，避免 IDE 做多余操作。


set(CMAKE_PROJECT_TOP_LEVEL_INCLUDES
    ${CMAKE_SOURCE_DIR}/cmake/platform_settings.cmake
    ${CMAKE_SOURCE_DIR}/cmake/recipes_bootstrap.cmake
    ${CMAKE_SOURCE_DIR}/cmake/conan_provider.cmake
    CACHE STRING "" FORCE)
#---step 4 ---          CMake 3.24+ 支持的机制，用来指定在项目级自动 include 的脚本,platform_settings.cmake：平台相关设置（编译选项、警告级别等）
#recipes_bootstrap.cmake：构建前的“引导”脚本，可能设置依赖路径、构建选项。
#conan_provider.cmake：把 Conan 集成到 CMake 的依赖查找里（conan 作为包管理器）。



project(${PROJECT} VERSION ${AMNEZIAVPN_VERSION}
        DESCRIPTION "AmneziaVPN"
        HOMEPAGE_URL "https://amnezia.org/"
)
#=== step 5 ===         真正创建 CMake 项目 AmneziaVPN，版本设为 4.9.0.3； 附带描述和主页链接，主要用于 IDE 展示、打包元数据。




# trigger conan to kick off `conan install` globally
find_package(OpenSSL REQUIRED)
if (PREBUILTS_ONLY)
    return()
endif()
#-- step 6 --       触发 Conan / 依赖检查,查找 OpenSSL 库，找不到就直接失败。
#    结合 conan_provider.cmake，这一步还可能触发 Conan 去执行 conan install，把依赖装到本地。
#.   如果设置了 -DPREBUILTS_ONLY=ON，就直接返回，不再继续后续配置。适合只想用预编译产物、不想重新构建 client/service 的场景。




string(TIMESTAMP CURRENT_DATE "%Y-%m-%d")
set(RELEASE_DATE "${CURRENT_DATE}")

set(APP_MAJOR_VERSION ${CMAKE_PROJECT_VERSION_MAJOR}.${CMAKE_PROJECT_VERSION_MINOR}.${CMAKE_PROJECT_VERSION_PATCH})
set(APP_ANDROID_VERSION_CODE 2131)

#=== step 7         取当前日期，格式为 YYYY-MM-DD，用于构建时写入版本信息或 About 对话框。
#.              APP_MAJOR_VERSION：从 4.9.0.3 中取 MAJOR.MINOR.PATCH（三段），生成 4.9.0 之类的版本号，用于显示。
#               APP_ANDROID_VERSION_CODE：Android 的整数版本号，用于 versionCode，影响升级顺序。




if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(MZ_PLATFORM_NAME "linux")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
    set(MZ_PLATFORM_NAME "windows")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
    set(MZ_PLATFORM_NAME "macos")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Android")
    set(MZ_PLATFORM_NAME "android")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "iOS")
    set(MZ_PLATFORM_NAME "ios")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Emscripten")
    set(MZ_PLATFORM_NAME "wasm")
endif()

#===== step 8       按平台判定 MZ_PLATFORM_NAME,这个变量很可能在子 CMake 脚本里用于选择平台特定的源码、资源或编译选项。
#=====              根据 CMAKE_SYSTEM_NAME 判定当前构建平台，并设置一个更统一/内部用的标识 MZ_PLATFORM_NAME



set(QT_BUILD_TOOLS_WHEN_CROSS_COMPILING ON)
#=====  step 9      Qt 跨编译时的工具构建,当进行跨编译（比如在 macOS 上编 Android/iOS）时，让 Qt 在本地也构建需要的 host 工具（比如 moc, rcc 等），以确保跨编译正常。

if(APPLE AND NOT IOS)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(AMN_PF_RULE_IDENTITY "user { root }")
    else()
        set(AMN_PF_RULE_IDENTITY "group { amnvpn }")
    endif()

    configure_file(
        "${CMAKE_SOURCE_DIR}/deploy/data/pf-templates/amn.400.allowPIA.conf.in"
        "${CMAKE_CURRENT_BINARY_DIR}/amn.400.allowPIA.conf"
        @ONLY
    )

    file(COPY_FILE
        "${CMAKE_CURRENT_BINARY_DIR}/amn.400.allowPIA.conf"
        "${CMAKE_SOURCE_DIR}/deploy/data/macos/pf/amn.400.allowPIA.conf"
        ONLY_IF_DIFFERENT
    )
endif()

#==== step 10   macOS 特殊处理：pf 规则模板
#===            只在 macOS（APPLE 且不是 iOS）执行，做的是防火墙 pf 规则的自动生成/更新：
#===                    1)根据 CMAKE_BUILD_TYPE：Debug 模式下，AMN_PF_RULE_IDENTITY 设置为 user { root }；
#===                    2)Release 模式下，设置为 group { amnvpn }（说明生产环境希望以特定用户组来运行 pf 规则）。
#===                    3)configure_file：把 amn.400.allowPIA.conf.in 模板文件处理为实际的 pf 配置文件，替换里面的 @AMN_PF_RULE_IDENTITY@ 等变量。输出到构建目录 amn.400.allowPIA.conf。
#===                    4)file(COPY_FILE ... ONLY_IF_DIFFERENT)：只有当新生成的 pf 文件与源路径不同，才复制到 deploy/data/macos/pf/。避免每次构建都改动源树里的同名文件。
#===            这块逻辑是为了保证 macOS 版 AmneziaVPN 的 pf 防火墙规则自动更新且区分 debug/release 身份。





add_subdirectory(client)

if(NOT IOS AND NOT ANDROID AND NOT MACOS_NE)
    add_subdirectory(service)
endif()

#===  step 11   组织子工程：client 和 service
#===    总是加入 client 子目录，说明这是 UI 或主应用部分。
#===    service 子目录只在非 iOS、非 Android、非 MACOS_NE 的平台加入，大概率是：
#===        1)桌面平台上的后台服务或系统服务守护进程；
#===        2)移动端可能用其他方式实现服务（或不需要单独 service 目标）。
#===    MACOS_NE 看名字像是某个“macOS Network Extension”开关，用来区分普通 macOS 应用和 NE 模式；如果是 NE 模式，就不构建单独的 service。





if ((LINUX AND NOT ANDROID) OR (APPLE AND NOT IOS AND NOT MACOS_NE) OR (WIN32))
    include(${CMAKE_SOURCE_DIR}/cmake/CPack.cmake)
endif()

#=== step 12       打包配置（CPack）
#===        只在桌面类平台启用 CPack 打包逻辑：
#===            1)Linux（非 Android）；
#===            2)macOS（非 iOS，非 MACOS_NE）；
#===            3)Windows
#===    CPack.cmake 里通常会定义安装规则、打包格式（deb/rpm/dmg/nsis 等）和版本信息，最终生成安装包。