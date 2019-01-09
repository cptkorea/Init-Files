if status --is-login
    set PATH $PATH ~/bin
    if test -d ~/devtools/buck/bin
       set PATH $PATH ~/devtools/buck/bin
    end
    if test -d /snap/bin
       set PATH $PATH /snap/bin
    end
    if test -d ~/.cargo/bin
       set PATH $PATH ~/.cargo/bin
    end
end

# export EDITOR=ec
# export VISUAL=ec

# export FBANDROID_DIR=/Users/doty/fbsource/fbandroid
# alias quicklog_update=/Users/doty/fbsource/fbandroid/scripts/quicklog/quicklog_update.sh
# alias qlu=quicklog_update

# # added by setup_fb4a.sh
# export ANDROID_SDK=/opt/android_sdk
# export ANDROID_NDK_REPOSITORY=/opt/android_ndk
# export ANDROID_HOME={ANDROID_SDK}
# export PATH={PATH}:{ANDROID_SDK}/tools:{ANDROID_SDK}/platform-tools
