#!/bin/bash
# Metashell - Interactive C++ template metaprogramming shell
# Copyright (C) 2021, Abel Sinkovics (abel@sinkovics.hu)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e

if [ ! -d cmake ]
then
  echo "Please run this script from the root directory of the Metashell source code"
  exit 1
fi

cd 3rd
  cp yaml-cpp/CMakeLists.txt backup.txt

  rm -rf yaml-cpp
  git clone 'https://github.com/jbeder/yaml-cpp.git'
  cd yaml-cpp
    echo
    echo -n "Upgrading yaml-cpp to commit "
    git rev-parse HEAD
    echo

    rm -rf \
      .??* \
      docs \
      test \
      util \
      BUILD.bazel \
      *.txt \
      *.md \
      WORKSPACE \
      *.yml \
      *.in
  cd ..

  mv backup.txt yaml-cpp/CMakeLists.txt
cd ..
