% specparam_version() - Get specparam version information.
%
% Usage:
%   >> specparam_version()
%
% Notes
%   This function returns versions of both the installed specparam in Python, and of this Matlab wrapper.

function specparam_version()

    % Get the version of the Python specparam package
    specparam_py_version = string(py.pkg_resources.get_distribution('specparam').version);

    % Set the version number of the matlab wrapper
    specparam_wrapper_version = "1.0.0";

    % Display versions
    disp('Current version of specparam: ' + specparam_py_version)
    disp('Current version of Wrapper:   ' + specparam_wrapper_version)

end
